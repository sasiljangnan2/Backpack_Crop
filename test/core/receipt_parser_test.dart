import 'package:backpack/features/expense/data/expense_models.dart';
import 'package:backpack/features/expense/data/receipt_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 세븐일레븐 다카마쓰역점 영수증을 ML Kit가 줄 단위로 읽은 모양 (로고는 "予"로, 큰 글자는 띄어서 읽힌다)
const _sevenEleven = [
  ReceiptLine('予セブンイレブン'),
  ReceiptLine('Kiosk高松駅店'),
  ReceiptLine('香川県高松市浜ノ町1−20'),
  ReceiptLine('電話:087-811-2325 レジ#3'),
  ReceiptLine('事業者登録番号T4470001001847'),
  ReceiptLine('2026年03月08日(日) 20:40 責048'),
  ReceiptLine('領 収 書'),
  ReceiptLine('7P蒙古タンメン中本辛旨味噌'),
  ReceiptLine('@240x 3 *720'),
  ReceiptLine('チキン南蛮 *298'),
  ReceiptLine('ねぎ塩豚カルビ弁当 *520'),
  ReceiptLine('|味付海苔炭火焼紅しゃけ *215'),
  ReceiptLine('味付のり海老マヨネーズ *208'),
  ReceiptLine('7プレミアム味付き半熟ゆで *190'),
  ReceiptLine('ポッカ キレートレモンムグミ 155ml|'),
  ReceiptLine('@175x 2 *350'),
  ReceiptLine('7P鉄板焼ハンバーグチーズイン *298'),
  ReceiptLine('小 計 (税抜 8%) ¥2,799'),
  ReceiptLine('消費税等 ( 8%) ¥223'),
  ReceiptLine('合 計 ¥3.022'),
  ReceiptLine('(税率 8%対象 ¥3,022)'),
  ReceiptLine('(内消費税等 8% ¥223)'),
  ReceiptLine('お 預 り ¥3.022'),
  ReceiptLine('お 釣 ¥0'),
  ReceiptLine('お買上明細は上記のとおりです。'),
  ReceiptLine('[*]マークは軽減税率対象です。'),
  ReceiptLine('伝票番号 260-308-324-6525'),
];

void main() {
  test('편의점 영수증: "*298"은 세율 표시, "@240x 3"은 윗줄 항목의 수량, 주소는 항목이 아니다', () {
    final scan = ReceiptParser.parse(_sevenEleven);

    expect(scan.store, 'セブンイレブン Kiosk高松駅店');
    expect(scan.date, DateTime(2026, 3, 8));
    expect(scan.time, const TimeOfDay(hour: 20, minute: 40));
    expect(scan.items.map((i) => i.name), [
      '7P蒙古タンメン中本辛旨味噌',
      'チキン南蛮',
      'ねぎ塩豚カルビ弁当',
      '味付海苔炭火焼紅しゃけ',
      '味付のり海老マヨネーズ',
      '7プレミアム味付き半熟ゆで',
      'ポッカ キレートレモンムグミ 155ml',
      '7P鉄板焼ハンバーグチーズイン',
    ]);
    expect(scan.items.map((i) => i.amount), [
      720,
      298,
      520,
      215,
      208,
      190,
      350,
      298,
    ]);
    expect(scan.items.map((i) => i.qty), [3, 1, 1, 1, 1, 1, 2, 1]);
    expect(scan.items.first.unitPrice, 240);
    // 외세: 항목 합계 2,799 + 소비세 223 = 합계 3,022
    expect(scan.total, 3022);
    expect(scan.taxIncluded, isFalse);
    expect(scan.addedTax, 223);
    expect(scan.category, ExpenseCategory.food);
  });

  test('큰 글자 합계가 끊겨 읽혀도("¥3.0 22" · "22") 다른 줄과 맞는 총액을 쓴다', () {
    for (final broken in ['合 計 ¥3.0 22', '合 計 22']) {
      final scan = ReceiptParser.parse([
        for (final line in _sevenEleven)
          line.text.startsWith('合') ? ReceiptLine(broken) : line,
      ]);
      expect(scan.total, 3022, reason: broken);
      expect(scan.addedTax, 223, reason: broken);
    }
  });

  test('합계 줄을 못 읽어도 소계 + 소비세로 총액을 맞춘다', () {
    final scan = ReceiptParser.parse([
      for (final line in _sevenEleven)
        if (!line.text.startsWith('合')) line,
    ]);

    expect(scan.total, 3022);
    expect(scan.addedTax, 223);
  });

  test('서버(Gemini)가 읽은 결과는 번역 · 세금을 그대로 쓴다', () {
    final scan = ReceiptScan.fromJson({
      'store': 'セブン-イレブン Kiosk高松駅店',
      'storeKo': '세븐일레븐 키오스크 다카마쓰역점',
      'date': '2026-03-08',
      'time': '20:40',
      'currency': 'JPY',
      'items': [
        {
          'name': 'チキン南蛮',
          'nameKo': '치킨 난반',
          'qty': 1,
          'unitPrice': 298,
          'amount': 298,
        },
        {
          'name': 'ポッカ キレートレモン',
          'qty': 2,
          'unitPrice': 175,
          'amount': 350,
          'unclear': true,
        },
      ],
      'subtotal': 648,
      'tax': 51,
      'taxIncluded': false,
      'total': 699,
    });

    expect(scan.fromServer, isTrue);
    expect(scan.storeKo, '세븐일레븐 키오스크 다카마쓰역점');
    expect(scan.time, const TimeOfDay(hour: 20, minute: 40));
    expect(scan.items.first.nameKo, '치킨 난반');
    expect(scan.items.last.nameKo, isNull);
    expect(scan.items.last.qty, 2);
    expect(scan.needsCheckCount, 1);
    expect(scan.addedTax, 51);
  });

  test('일본 영수증: 가게 · 일시 · 합계 · 항목(수량)을 읽고 세금 · 받은 돈은 뺀다', () {
    final scan = ReceiptParser.parse(const [
      ReceiptLine('一蘭 難波店', .95),
      ReceiptLine('TEL 06-1234-5678', .9),
      ReceiptLine('2026/10/03 13:58', .97),
      ReceiptLine('とんこつラーメン ×5 ¥4,900', .93),
      ReceiptLine('生ビール ×3 ¥1,650', .9),
      ReceiptLine('餃子 ×1 ¥390', .52),
      ReceiptLine('替玉 ×1 ¥420', .32),
      ReceiptLine('(内消費税 ¥669)', .9),
      ReceiptLine('合計 ¥7,360', .96),
      ReceiptLine('お預り ¥10,000', .9),
      ReceiptLine('お釣り ¥2,640', .9),
    ]);

    expect(scan.store, '一蘭 難波店');
    expect(scan.date, DateTime(2026, 10, 3));
    expect(scan.time, const TimeOfDay(hour: 13, minute: 58));
    expect(scan.total, 7360);
    expect(scan.items.map((i) => i.name), ['とんこつラーメン', '生ビール', '餃子', '替玉']);
    expect(scan.items.map((i) => i.qty), [5, 3, 1, 1]);
    expect(scan.items.fold<double>(0, (s, i) => s + i.amount), 7360);
    // 신뢰도가 낮은 항목은 확인이 필요하다
    expect(scan.needsCheckCount, 1);
    expect(scan.items.last.needsCheck, isTrue);
    expect(scan.category, ExpenseCategory.food);
  });

  test('한국 영수증: 전각 숫자 · 원 표시 · 합계 다음 줄 금액', () {
    final scan = ReceiptParser.parse(const [
      ReceiptLine('스타벅스 강남점'),
      ReceiptLine('2026-11-02 09:15'),
      ReceiptLine('아메리카노 2개 9,000원'),
      ReceiptLine('치즈케이크 ６,５００원'),
      ReceiptLine('부가세 1,409'),
      ReceiptLine('합계'),
      ReceiptLine('15,500원'),
      ReceiptLine('카드 승인 15,500'),
    ]);

    expect(scan.store, '스타벅스 강남점');
    expect(scan.total, 15500);
    expect(scan.items.map((i) => i.name), ['아메리카노', '치즈케이크']);
    expect(scan.items.first.qty, 2);
    expect(scan.items.last.amount, 6500);
    expect(scan.needsCheckCount, 0);
  });

  test('소수점이 있는 통화는 센트까지 읽는다', () {
    final scan = ReceiptParser.parse(const [
      ReceiptLine('Blue Bottle Coffee'),
      ReceiptLine('Latte 5.75'),
      ReceiptLine('Croissant 4.25'),
      ReceiptLine('Subtotal 10.00'),
      ReceiptLine('Tax 0.89'),
      ReceiptLine('TOTAL \$10.89'),
    ], decimals: true);

    expect(scan.total, 10.89);
    expect(scan.items.map((i) => i.amount), [5.75, 4.25]);
  });

  test('총액 줄이 없으면 항목 합계를 쓰고, 글자를 못 읽으면 총액이 없다', () {
    final summed = ReceiptParser.parse(const [
      ReceiptLine('ローソン'),
      ReceiptLine('おにぎり 160'),
      ReceiptLine('お茶 150'),
    ]);
    expect(summed.total, 310);
    expect(summed.category, ExpenseCategory.food);

    expect(ReceiptParser.parse(const [ReceiptLine('...')]).total, isNull);
  });

  test('가게 이름으로 분류를 추천한다', () {
    expect(ReceiptParser.guessCategory('東横INN 新大阪'), ExpenseCategory.lodging);
    expect(ReceiptParser.guessCategory('JR西日本 大阪駅'), ExpenseCategory.transport);
    expect(
      ReceiptParser.guessCategory('ドン・キホーテ 道頓堀'),
      ExpenseCategory.shopping,
    );
    expect(ReceiptParser.guessCategory('이치란 라멘'), ExpenseCategory.food);
  });
}
