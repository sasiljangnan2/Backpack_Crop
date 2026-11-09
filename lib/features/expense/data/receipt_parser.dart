import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/network/json.dart';
import 'expense_models.dart';

// ReceiptScan의 time 필드와 이름이 겹쳐 json.dart의 time()을 밖에서 부른다
TimeOfDay? _timeOrNull(Object? value) => value == null ? null : time(value);

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
    this.nameKo,
    this.unitPrice,
    this.confidence,
    this.unclear = false,
  });

  /// 서버(Gemini)가 읽은 항목 (POST /receipts/scan)
  factory ReceiptItem.fromJson(Json json) => ReceiptItem(
    name: json['name'] as String,
    nameKo: json['nameKo'] as String?,
    qty: integerOrNull(json['qty']) ?? 1,
    unitPrice: decimalOrNull(json['unitPrice']),
    amount: decimal(json['amount']),
    unclear: json['unclear'] as bool? ?? false,
  );

  String name;

  /// 외국어 이름의 한국어 번역 (서버가 읽었을 때만)
  final String? nameKo;
  double amount;
  int qty;
  final double? unitPrice;

  /// 기기 안 OCR의 인식 신뢰도 (0~1). 서버가 읽었으면 null
  final double? confidence;

  /// 서버가 글자가 흐려 확인이 필요하다고 한 줄
  final bool unclear;

  /// 사람이 금액을 확인해야 하는 항목 (스토리보드 BP-EX-003 ⑤)
  bool get needsCheck =>
      unclear || (confidence ?? 1) < ReceiptParser.lowConfidence;
}

/// 영수증에서 읽은 결제 정보 (BP-EX-002 → EX-003)
class ReceiptScan {
  ReceiptScan({
    this.store,
    this.storeKo,
    this.total,
    this.subtotal,
    this.tax,
    this.taxIncluded = true,
    this.date,
    this.time,
    this.currency,
    this.fromServer = false,
    List<ReceiptItem>? items,
  }) : items = items ?? [];

  factory ReceiptScan.fromJson(Json json) => ReceiptScan(
    store: json['store'] as String?,
    storeKo: json['storeKo'] as String?,
    total: decimalOrNull(json['total']),
    subtotal: decimalOrNull(json['subtotal']),
    tax: decimalOrNull(json['tax']),
    taxIncluded: json['taxIncluded'] as bool? ?? true,
    date: dateOrNull(json['date']),
    time: _timeOrNull(json['time']),
    currency: json['currency'] as String?,
    fromServer: true,
    items: list(json['items'], ReceiptItem.fromJson),
  );

  final String? store;

  /// 외국어 가게 이름의 한국어 번역 (서버가 읽었을 때만)
  final String? storeKo;
  final double? total;
  final double? subtotal;

  /// 소비세 · 부가세. [taxIncluded]가 false면 항목 금액에 더해진다 (일본 외세)
  final double? tax;
  final bool taxIncluded;
  final DateTime? date;
  final TimeOfDay? time;

  /// 영수증 통화 (서버가 읽었을 때만, 예: JPY)
  final String? currency;

  /// 서버(Gemini)가 읽었으면 true, 기기 안 OCR이면 false
  final bool fromServer;
  final List<ReceiptItem> items;

  int get needsCheckCount => items.where((i) => i.needsCheck).length;

  double get itemsSum => items.fold<double>(0, (sum, i) => sum + i.amount);

  /// 항목 합계에 더해야 총액이 되는 세금 (외세). 없거나 맞지 않으면 null
  double? get addedTax {
    final tax = this.tax ?? 0;
    final total = this.total;
    if (taxIncluded || tax <= 0 || total == null || items.isEmpty) {
      return null;
    }
    return (itemsSum + tax - total).abs() < 0.005 ? tax : null;
  }

  ExpenseCategory get category => ReceiptParser.guessCategory(
    [store ?? '', for (final i in items) i.name].join(' '),
  );
}

/// 영수증 글자에서 가게 · 날짜 · 총액 · 항목을 찾는다 (한국어 · 일본어 · 영어 영수증).
/// 서버(Gemini)에 닿지 못할 때 쓰는 기기 안 OCR(ML Kit) 결과용이다
abstract final class ReceiptParser {
  // ML Kit의 일본어 · 한국어 모델은 맞게 읽어도 신뢰도가 0.5 안팎이다. 그보다 확실히 낮을 때만 확인을 부탁한다
  static const lowConfidence = 0.4;

  // 띄어쓰기를 지운 소문자 줄과 비교한다 ("合 計" · "小 計"처럼 큰 글자는 떨어져 읽힌다)
  static const _totalWords = [
    '합계',
    '총액',
    '총금액',
    '결제금액',
    '받을금액',
    '청구금액',
    '판매금액',
    'total',
    'amountdue',
    '合計',
    '総計',
    'お会計',
    'ご請求',
  ];
  static const _subtotalWords = ['소계', 'subtotal', '小計'];
  static const _taxWords = ['消費税', '税額', '부가세', '부가가치세', 'vat', 'tax'];
  // 세금이 항목 금액에 이미 들어 있다는 표시 (내세)
  static const _taxIncludedWords = ['内', '포함', 'incl', '税込'];
  static const _paidWords = [
    'お預',
    '預り',
    '預かり',
    '받은금액',
    '받은돈',
    'cash',
    'tendered',
  ];
  static const _changeWords = ['お釣', '釣銭', '釣り', '거스름', '잔돈', 'change'];
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
    '수량합계',
    '伝票',
    'お買上',
    'お買い上げ',
    'マーク',
    'レジ#',
  ];
  // 로고가 다른 글자로 읽혀도 가게 이름을 바로잡을 수 있게 흔한 체인 이름을 안다
  static const _chains = [
    'セブン-イレブン',
    'セブンイレブン',
    'ファミリーマート',
    'ローソン',
    'ミニストップ',
    'デイリーヤマザキ',
    'セイコーマート',
    'ドン・キホーテ',
    'マツモトキヨシ',
    'ユニクロ',
    '세븐일레븐',
    '이마트24',
    '7-ELEVEN',
    'FamilyMart',
    'LAWSON',
  ];
  static const _convenience = [
    'セブン',
    'ファミリーマート',
    'ローソン',
    'ミニストップ',
    'デイリーヤマザキ',
    'コンビニ',
    '세븐일레븐',
    '편의점',
    'gs25',
    'cu ',
    '이마트24',
    '7-eleven',
    'familymart',
    'lawson',
  ];

  static final _date = RegExp(
    r'(20\d{2})\s*[./\-年]\s*(\d{1,2})\s*[./\-月]\s*(\d{1,2})',
  );
  static final _time = RegExp(r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)');
  // 금액 바로 앞의 세율 표시 ("*298" · "※520" · "軽 190")는 곱하기나 수량이 아니다
  static final _taxMark = RegExp(
    r'[*※#軽]\s*(?=[¥₩$€£\\]?\s*-?[0-9][0-9,.]*\s*(?:円|원|엔)?\s*[*※#軽外内]?\s*$)',
  );
  // 줄 끝의 금액. 숫자 · 하이픈 · 슬래시 · 콜론 바로 뒤에서 시작하는 숫자("1-20" · "20:40")와
  // "×5"처럼 수량 표시 바로 뒤의 숫자는 금액이 아니다
  static final _amount = RegExp(
    r'(?<![x×X]\s*)(?<![\d\-−‐/:.,])[¥₩$€£\\]?\s*(-?[0-9][0-9,.]*)\s*(?:円|원|엔)?\s*[*※#軽外内]?\s*\)?\s*$',
  );
  static final _qty = RegExp(
    r'(?:[x×X]\s*(\d{1,3})(?!\d))|(?:(\d{1,3})\s*(?:개|個|点|EA|ea|pcs)(?![가-힣]))',
  );
  static final _moneyTail = RegExp(
    r'[¥₩$€£\\]\s*(-?[0-9][0-9,.\s]*)\s*(?:円|원|엔)?\s*\)?\s*$',
  );
  static final _unitPrice = RegExp(r'@\s*[¥₩$€£]?\s*([0-9][0-9,.]*)');
  // 단가 · 수량 열 ("아메리카노 4,500 2")
  static final _priceQtyTail = RegExp(r'\s([0-9][0-9,.]*)\s+(\d{1,3})\s*$');
  static final _phone = RegExp(r'\d{2,4}\s*[-−‐]\s*\d{2,4}\s*[-−‐]\s*\d{3,4}');
  static final _addresses = [
    RegExp(r'[都道府県].*[市区町村郡]'),
    RegExp(r'\d+\s*丁目'),
    RegExp(r'[市区町村].*\d+\s*[-−‐]\s*\d+'),
    RegExp(r'(시|군|구)\s?[가-힣0-9]*\s?(동|로|길|읍|면)\s?\d'),
  ];
  static final _leadingJunk = RegExp(r'^[|│｜・·*※#\-_=\s]+');

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

    // 합계 · 소계 · 세금 · 받은 돈 · 거스름돈 줄 (금액이 다음 줄에 있으면 다음 줄)
    double? total;
    double? subtotal;
    double? addedTax;
    double? includedTax;
    double? paid;
    double? change;
    // "(税率 8%対象 ¥3,022)": 세율별 과세 대상 금액 (세금 포함). 총액을 맞춰 보는 데만 쓴다
    double? taxable;
    var end = lines.length;
    for (var i = 0; i < lines.length; i++) {
      final key = _compact(lines[i].text);
      bool has(List<String> words) => words.any(key.contains);
      double? value() {
        for (final j in [i, i + 1]) {
          if (j < lines.length) {
            final text = _stripTaxMark(lines[j].text);
            final money = _moneyTail.firstMatch(text);
            final v = money != null
                ? _amountOf(money[1]!.replaceAll(RegExp(r'\s'), ''), decimals)
                : _amountOf(text, decimals);
            if (v != null && (j == i || !_hasLetters(lines[j].text))) {
              return v;
            }
          }
        }
        return null;
      }

      if (has(_subtotalWords)) {
        subtotal ??= value();
        end = math.min(end, i);
      } else if (has(_totalWords) &&
          !key.contains('点') &&
          !key.contains('수량')) {
        total ??= value();
        end = math.min(end, i);
      } else if (key.contains('対象')) {
        taxable ??= value();
      } else if (has(_taxWords)) {
        final v = value();
        if (has(_taxIncludedWords)) {
          includedTax ??= v;
        } else {
          addedTax ??= v;
        }
      } else if (has(_paidWords)) {
        paid ??= value();
      } else if (has(_changeWords)) {
        change ??= _amountOf(lines[i].text, decimals) ?? 0;
      }
    }
    // 외세 영수증도 합계 아래에 "(内消費税等 ¥223)"을 적으므로, 더하는 세금 줄이 있으면 외세로 본다
    // (ReceiptScan.addedTax가 항목 합계 + 세금 = 총액인지 다시 확인한다)
    final taxIncluded = addedTax == null;

    final (store, storeEnd) = _storeOf(lines);
    final items = <ReceiptItem>[];
    // 이름만 있는 줄. 다음 줄이 "@240x 3 *720"처럼 금액만 있으면 이 이름의 항목이다
    String? pendingName;
    double? pendingConfidence;
    for (var i = storeEnd + 1; i < end; i++) {
      final line = lines[i];
      final text = _stripTaxMark(line.text);
      final key = _compact(text);
      if (_ignoreWords.any(key.contains) ||
          _date.hasMatch(text) ||
          _time.hasMatch(text) ||
          _phone.hasMatch(text) ||
          _addresses.any((a) => a.hasMatch(text))) {
        pendingName = null;
        continue;
      }
      final match = _amount.firstMatch(text);
      final value = match == null ? null : _amountOf(text, decimals);
      if (value == null || match == null) {
        final name = _cleanName(text);
        pendingName = _hasLetters(name) ? name : null;
        pendingConfidence = line.confidence;
        continue;
      }
      var name = text.substring(0, match.start);
      var qty = 1;
      double? unitPrice;
      final unit = _unitPrice.firstMatch(name);
      if (unit != null) {
        unitPrice = double.tryParse(unit[1]!.replaceAll(',', ''));
        name = name.replaceRange(unit.start, unit.end, ' ');
      }
      final q = _qty.firstMatch(name);
      if (q != null) {
        qty = int.parse(q[1] ?? q[2]!);
        name = name.replaceRange(q.start, q.end, ' ');
      } else {
        final tail = _priceQtyTail.firstMatch(name);
        final price = tail == null
            ? null
            : double.tryParse(tail[1]!.replaceAll(',', ''));
        final n = tail == null ? null : int.tryParse(tail[2]!);
        if (price != null &&
            n != null &&
            n > 0 &&
            (price * n - value).abs() < 0.01) {
          qty = n;
          unitPrice = price;
          name = name.substring(0, tail!.start);
        }
      }
      name = _cleanName(name);
      var confidence = line.confidence;
      if (!_hasLetters(name)) {
        if (pendingName == null) {
          continue;
        }
        name = pendingName;
        confidence = _min(pendingConfidence, line.confidence);
      }
      pendingName = null;
      if (value < 0) {
        // 할인: 바로 위 항목에서 뺀다
        if (items.isNotEmpty && items.last.amount + value > 0) {
          items.last.amount += value;
        }
        continue;
      }
      items.add(
        ReceiptItem(
          name: name,
          amount: value,
          qty: math.max(1, qty),
          unitPrice: unitPrice,
          confidence: confidence,
        ),
      );
    }

    total = _pickTotal(
      total: total,
      itemsSum: items.fold<double>(0, (sum, i) => sum + i.amount),
      subtotal: subtotal,
      others: [
        if (subtotal != null && addedTax != null) subtotal + addedTax,
        if (paid != null && paid - (change ?? 0) > 0) paid - (change ?? 0),
        ?taxable,
        ?subtotal,
      ],
      addedTax: addedTax,
    );
    if (total == null) {
      // 총액을 찾을 단서가 하나도 없으면 가장 큰 금액
      if (items.isEmpty) {
        for (final line in lines) {
          final value = _amountOf(line.text, decimals);
          if (value != null &&
              !_date.hasMatch(line.text) &&
              !_time.hasMatch(line.text) &&
              !_phone.hasMatch(line.text)) {
            total = math.max(total ?? 0, value);
          }
        }
      }
    }
    return ReceiptScan(
      store: store,
      total: total,
      subtotal: subtotal,
      tax: taxIncluded ? includedTax : addedTax,
      taxIncluded: taxIncluded,
      date: date,
      time: time,
      items: items,
    );
  }

  /// 가게 이름으로 분류 추천 (사용자가 바꿀 수 있다)
  static ExpenseCategory guessCategory(String text) {
    final t = text.toLowerCase();
    bool any(List<String> words) => words.any(t.contains);
    // 편의점은 역 안에 있어도 대부분 먹을거리다
    if (any(_convenience)) {
      return ExpenseCategory.food;
    }
    if (any(['hotel', '호텔', 'ホテル', '旅館', 'inn', '게스트하우스', 'hostel'])) {
      return ExpenseCategory.lodging;
    }
    if (any([
          'taxi',
          '택시',
          'タクシー',
          'jr',
          '철도',
          '지하철',
          'metro',
          'subway',
          'bus',
          '버스',
          'バス',
          '交通',
        ]) ||
        (t.contains('駅') && !t.contains('店'))) {
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
    ])) {
      return ExpenseCategory.shopping;
    }
    return ExpenseCategory.food;
  }

  /// 합계 줄 값이 항목 · 소계보다 작으면(큰 글자 "¥3.022"가 "22"로 읽힘) 믿지 않고,
  /// 다른 단서(소계 + 외세, 받은 돈 − 거스름돈, 과세 대상 금액, 소계, 항목 합계) 중 서로 맞는 값을 쓴다
  static double? _pickTotal({
    required double? total,
    required double itemsSum,
    required double? subtotal,
    required List<double> others,
    required double? addedTax,
  }) {
    final floor = math.max(itemsSum, subtotal ?? 0) - 0.5;
    if (total != null && total >= floor) {
      return total;
    }
    final candidates = [
      ...others,
      if (itemsSum > 0) itemsSum + (addedTax ?? 0),
    ];
    for (final (i, v) in candidates.indexed) {
      if (candidates.indexed.any((o) => o.$1 != i && (o.$2 - v).abs() < 0.5)) {
        return v;
      }
    }
    return candidates.where((v) => v >= floor).firstOrNull ??
        candidates.firstOrNull ??
        total;
  }

  static double? _min(double? a, double? b) =>
      a == null ? b : (b == null ? a : math.min(a, b));

  static String _compact(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static String _stripTaxMark(String text) => text.replaceAll(_taxMark, ' ');

  static String _cleanName(String text) => text
      .replaceFirst(_leadingJunk, '')
      .replaceAll(RegExp(r'[\s.·:|│｜]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double? _amountOf(String text, bool decimals) {
    final m = _amount.firstMatch(text);
    if (m == null) {
      return null;
    }
    var raw = m[1]!;
    final negative = raw.startsWith('-');
    raw = raw.replaceFirst('-', '');
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
    return negative ? -value : value;
  }

  /// 가게 이름과 그 줄 번호. 다음 줄이 지점 이름("高松駅店" · "강남점")이면 붙인다
  static (String?, int) _storeOf(List<ReceiptLine> lines) {
    for (var i = 0; i < math.min(6, lines.length); i++) {
      var text = lines[i].text
          .replaceAll(RegExp(r'[【】\[\]「」『』<>()（）*★☆=_]+'), ' ')
          .trim();
      final lower = text.toLowerCase();
      if (text.length < 2 ||
          !_hasLetters(text) ||
          _date.hasMatch(text) ||
          _time.hasMatch(text) ||
          _phone.hasMatch(text) ||
          _addresses.any((a) => a.hasMatch(text)) ||
          _ignoreWords.any(lower.contains) ||
          _totalWords.any(_compact(text).contains)) {
        continue;
      }
      final digits = RegExp(r'\d').allMatches(text).length;
      if (digits * 2 > text.length) {
        continue;
      }
      final chain = _chains
          .map((c) => (c, text.toLowerCase().indexOf(c.toLowerCase())))
          .where((c) => c.$2 >= 0)
          .firstOrNull;
      if (chain != null) {
        // 로고가 "予" 같은 글자로 읽혀 앞에 붙은 것을 지운다
        text = text.substring(chain.$2).trim();
      }
      var end = i;
      if (i + 1 < lines.length) {
        final next = lines[i + 1].text.trim();
        if (RegExp(r'(店|점|店舗)$').hasMatch(next) &&
            _amountOf(next, false) == null &&
            !_addresses.any((a) => a.hasMatch(next))) {
          text = '$text $next';
          end = i + 1;
        }
      }
      return (text, end);
    }
    return (null, -1);
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
