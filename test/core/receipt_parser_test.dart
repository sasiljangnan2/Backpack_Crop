import 'package:backpack/features/expense/data/expense_models.dart';
import 'package:backpack/features/expense/data/receipt_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(scan.confidence, isNull);
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
    expect(ReceiptParser.guessCategory('ドン・キホーテ 道頓堀'), ExpenseCategory.shopping);
    expect(ReceiptParser.guessCategory('이치란 라멘'), ExpenseCategory.food);
  });
}
