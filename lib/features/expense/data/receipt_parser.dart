import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'expense_models.dart';

/// OCR이 읽은 한 줄 (같은 높이의 글자를 왼쪽부터 이어 붙인 것). [confidence]는 0~1, 모르면 null
class ReceiptLine {
  const ReceiptLine(this.text, [this.confidence]);

  final String text;
  final double? confidence;
}

class ReceiptItem {
  ReceiptItem({
    required this.name,
    required this.amount,
    this.qty = 1,
    this.confidence,
  });

  String name;
  double amount;
  int qty;
  final double? confidence;

  /// 인식 신뢰도가 낮아 사람이 확인해야 하는 항목 (스토리보드 BP-EX-003 ⑤)
  bool get needsCheck => (confidence ?? 1) < ReceiptParser.lowConfidence;
}

/// 영수증에서 읽은 결제 정보 (BP-EX-002 → EX-003)
class ReceiptScan {
  ReceiptScan({
    this.store,
    this.total,
    this.date,
    this.time,
    this.totalConfidence,
    List<ReceiptItem>? items,
  }) : items = items ?? [];

  final String? store;
  final double? total;
  final DateTime? date;
  final TimeOfDay? time;
  final double? totalConfidence;
  final List<ReceiptItem> items;

  /// 항목 · 총액 인식 신뢰도 평균 (0~1). 기기가 신뢰도를 주지 않으면 null
  double? get confidence {
    final values = [
      ?totalConfidence,
      for (final item in items) ?item.confidence,
    ];
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  int get needsCheckCount => items.where((i) => i.needsCheck).length;

  ExpenseCategory get category => ReceiptParser.guessCategory(
    [store ?? '', for (final i in items) i.name].join(' '),
  );
}

/// 영수증 글자에서 가게 · 날짜 · 총액 · 항목을 찾는다 (한국어 · 일본어 · 영어 영수증).
/// 기기 안 OCR(ML Kit) 결과만 쓰고 서버로 보내지 않는다
abstract final class ReceiptParser {
  // ML Kit의 일본어 · 한국어 모델은 맞게 읽어도 신뢰도가 0.5 안팎이다. 그보다 확실히 낮을 때만 확인을 부탁한다
  static const lowConfidence = 0.4;

  static const _totalWords = [
    '합계',
    '총액',
    '총 금액',
    '총금액',
    '결제금액',
    '결제 금액',
    '받을금액',
    '청구금액',
    '판매금액',
    'total',
    'amount due',
    'grand total',
    '合計',
    '合 計',
    '総合計',
    '総計',
    'お会計',
    'ご請求',
    'お買上',
    'お買い上げ',
  ];
  static const _subtotalWords = ['소계', 'subtotal', 'sub total', '小計', '小 計'];
  // 항목이 아닌 줄 (세금 · 받은 돈 · 거스름돈 · 결제 수단 · 전화 · 포인트 등)
  static const _ignoreWords = [
    '부가세',
    '부가가치세',
    '과세',
    '면세',
    '봉사료',
    'vat',
    'tax',
    '税',
    '対象',
    '받은금액',
    '받은 금액',
    '거스름',
    '잔돈',
    '현금',
    '카드',
    '승인',
    'cash',
    'card',
    'change',
    'visa',
    'master',
    'お預',
    '預り',
    '預かり',
    'お釣',
    '釣銭',
    'クレジット',
    '電子マネー',
    'ポイント',
    '포인트',
    'point',
    '할인',
    '割引',
    'tel',
    '電話',
    '전화',
    'no.',
    '등록번호',
    '사업자',
    '登録番号',
    '領収',
    '영수증',
    'レシート',
    'receipt',
    '点数',
    '수량 합계',
  ];

  static final _date = RegExp(
    r'(20\d{2})\s*[./\-年]\s*(\d{1,2})\s*[./\-月]\s*(\d{1,2})',
  );
  static final _time = RegExp(r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)');
  // 줄 끝의 금액. "×5"처럼 수량 표시 바로 뒤의 숫자는 금액이 아니다
  static final _amount = RegExp(
    r'(?<![x×X*]\s*)[¥₩$€£\\]?\s*-?([0-9][0-9,.]*)\s*(?:円|원|엔)?\s*$',
  );
  static final _qty = RegExp(
    r'(?:[x×X＊*]\s*(\d{1,3})(?!\d))|(?:(\d{1,3})\s*(?:개|個|点|EA|ea|pcs)(?![가-힣]))',
  );
  static final _unitPrice = RegExp(r'@\s*[¥₩$€£]?\s*[0-9][0-9,.]*');

  /// [decimals]: 원 · 엔처럼 소수점이 없는 통화면 false ("1.650"을 1650으로 읽는다)
  static ReceiptScan parse(List<ReceiptLine> raw, {bool decimals = false}) {
    final lines = [
      for (final line in raw)
        if (_normalize(line.text).isNotEmpty)
          ReceiptLine(_normalize(line.text), line.confidence),
    ];
    DateTime? date;
    TimeOfDay? time;
    for (final line in lines) {
      final d = _date.firstMatch(line.text);
      if (d != null && date == null) {
        final parsed = DateTime.tryParse(
          '${d[1]}-${d[2]!.padLeft(2, '0')}-${d[3]!.padLeft(2, '0')}',
        );
        if (parsed != null && parsed.month == int.parse(d[2]!)) {
          date = parsed;
        }
      }
      final t = _time.firstMatch(line.text);
      if (t != null && time == null) {
        time = TimeOfDay(hour: int.parse(t[1]!), minute: int.parse(t[2]!));
      }
    }

    // 총액: "합계 · 合計 · TOTAL" 줄 (같은 줄에 없으면 다음 줄), 없으면 소계, 없으면 가장 큰 금액
    int totalIndex = -1;
    double? total;
    double? totalConfidence;
    for (final words in [_totalWords, _subtotalWords]) {
      for (var i = 0; i < lines.length && total == null; i++) {
        final text = lines[i].text.toLowerCase();
        final isSubtotal = _subtotalWords.any(text.contains);
        if (!words.any(text.contains) || (words == _totalWords && isSubtotal)) {
          continue;
        }
        for (final j in [i, i + 1]) {
          if (j < lines.length) {
            final value = _amountOf(lines[j].text, decimals);
            if (value != null) {
              total = value;
              totalConfidence = lines[j].confidence;
              totalIndex = i;
              break;
            }
          }
        }
      }
      if (total != null) {
        break;
      }
    }

    final store = _storeOf(lines);
    final items = <ReceiptItem>[];
    final end = totalIndex >= 0 ? totalIndex : lines.length;
    for (var i = 0; i < end; i++) {
      final line = lines[i];
      final lower = line.text.toLowerCase();
      if (line.text == store ||
          _ignoreWords.any(lower.contains) ||
          _totalWords.any(lower.contains) ||
          _subtotalWords.any(lower.contains) ||
          _date.hasMatch(line.text) ||
          _time.hasMatch(line.text)) {
        continue;
      }
      final value = _amountOf(line.text, decimals);
      final match = _amount.firstMatch(line.text);
      if (value == null || match == null) {
        continue;
      }
      var name = line.text.substring(0, match.start);
      var qty = 1;
      final q = _qty.firstMatch(name);
      if (q != null) {
        qty = int.parse(q[1] ?? q[2]!);
        name = name.replaceRange(q.start, q.end, ' ');
      }
      name = name
          .replaceAll(_unitPrice, ' ')
          .replaceAll(RegExp(r'[\s.·:]+$'), '')
          .trim();
      if (!_hasLetters(name)) {
        continue;
      }
      items.add(
        ReceiptItem(
          name: name,
          amount: value,
          qty: math.max(1, qty),
          confidence: line.confidence,
        ),
      );
    }

    if (total == null) {
      // 총액 줄을 못 찾으면 항목 합계, 항목도 없으면 가장 큰 금액
      if (items.isNotEmpty) {
        total = items.fold<double>(0, (sum, i) => sum + i.amount);
      } else {
        for (final line in lines) {
          final value = _amountOf(line.text, decimals);
          if (value != null &&
              !_date.hasMatch(line.text) &&
              !_time.hasMatch(line.text)) {
            total = math.max(total ?? 0, value);
          }
        }
      }
    }
    return ReceiptScan(
      store: store,
      total: total,
      date: date,
      time: time,
      totalConfidence: totalConfidence,
      items: items,
    );
  }

  /// 가게 이름으로 분류 추천 (사용자가 바꿀 수 있다)
  static ExpenseCategory guessCategory(String text) {
    final t = text.toLowerCase();
    bool any(List<String> words) => words.any(t.contains);
    if (any(['hotel', '호텔', 'ホテル', '旅館', 'inn', '게스트하우스', 'hostel'])) {
      return ExpenseCategory.lodging;
    }
    if (any([
      'taxi',
      '택시',
      'タクシー',
      '駅',
      'jr',
      '철도',
      '지하철',
      'metro',
      'subway',
      'bus',
      '버스',
      'バス',
      '交通',
    ])) {
      return ExpenseCategory.transport;
    }
    if (any([
      'museum',
      '박물관',
      '美術館',
      '博物館',
      'ticket',
      '입장',
      '入場',
      'チケット',
      'tour',
      '투어',
      'park',
      '파크',
    ])) {
      return ExpenseCategory.activity;
    }
    if (any([
      'mart',
      '마트',
      'マート',
      'store',
      'shop',
      '百貨店',
      'デパート',
      'ドラッグ',
      'drug',
      '백화점',
      'outlet',
      '아울렛',
      'ドン・キホーテ',
      'uniqlo',
      'ユニクロ',
      '편의점',
      'コンビニ',
    ])) {
      return ExpenseCategory.shopping;
    }
    return ExpenseCategory.food;
  }

  static double? _amountOf(String text, bool decimals) {
    final m = _amount.firstMatch(text);
    if (m == null) {
      return null;
    }
    final raw = m[1]!;
    double? value;
    if (decimals &&
        RegExp(r'^(\d{1,3}(,\d{3})*|\d+)\.\d{1,2}$').hasMatch(raw)) {
      value = double.tryParse(raw.replaceAll(',', ''));
    } else {
      // 1,650 · 1.650 · 1650 → 1650 (소수점 없는 통화)
      value = double.tryParse(raw.replaceAll(RegExp('[,.]'), ''));
    }
    if (value == null || value <= 0 || value > 50000000) {
      return null;
    }
    return value;
  }

  static String? _storeOf(List<ReceiptLine> lines) {
    for (final line in lines.take(6)) {
      final text = line.text
          .replaceAll(RegExp(r'[【】\[\]「」『』<>()（）*★☆=\-_]+'), ' ')
          .trim();
      final lower = text.toLowerCase();
      if (text.length < 2 ||
          !_hasLetters(text) ||
          _date.hasMatch(text) ||
          _time.hasMatch(text) ||
          _ignoreWords.any(lower.contains) ||
          _totalWords.any(lower.contains)) {
        continue;
      }
      final digits = RegExp(r'\d').allMatches(text).length;
      if (digits * 2 > text.length) {
        continue;
      }
      return text;
    }
    return null;
  }

  static bool _hasLetters(String text) =>
      RegExp(r'[A-Za-z가-힣぀-ヿ㐀-鿿]').allMatches(text).length >= 2;

  // 전각 숫자 · 기호를 반각으로 (１２３ → 123, ￥ → ¥)
  static String _normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune == 0xFFE5 || rune == 0xFF3C) {
        buffer.write('¥');
      } else if (rune >= 0xFF01 && rune <= 0xFF5E) {
        buffer.writeCharCode(rune - 0xFEE0);
      } else if (rune == 0x3000) {
        buffer.write(' ');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
