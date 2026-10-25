import 'package:backpack/core/network/json.dart';
import 'package:backpack/core/utils/format.dart';
import 'package:backpack/features/expense/data/expense_models.dart';
import 'package:backpack/features/notification/data/notification_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  group('json', () {
    test('날짜는 시간대 변환 없이 읽고 yyyy-MM-dd로 보낸다', () {
      final day = date('2026-10-03');
      expect(day, DateTime(2026, 10, 3));
      expect(dateParam(day), '2026-10-03');
      expect(dateParam(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    });

    test('시간은 HH:mm', () {
      expect(time('14:50'), const TimeOfDay(hour: 14, minute: 50));
      expect(time('09:05:00'), const TimeOfDay(hour: 9, minute: 5));
      expect(timeParam(const TimeOfDay(hour: 7, minute: 3)), '07:03');
    });

    test('서버 enum 이름과 Dart enum을 오간다', () {
      expect(
        enumOf(
          NotificationType.values,
          'EXPENSE_ADDED',
          NotificationType.tripDeleted,
        ),
        NotificationType.expenseAdded,
      );
      expect(
        enumOf(
          NotificationType.values,
          'SOMETHING_NEW',
          NotificationType.tripDeleted,
        ),
        NotificationType.tripDeleted,
      );
      expect(enumName(RateMode.prepaid), 'PREPAID');
      expect(enumName(NotificationRefType.settlementShare), 'SETTLEMENT_SHARE');
    });
  });

  group('format', () {
    test('원화 · 외화', () {
      expect(Fmt.krw(813899), '₩813,899');
      expect(Fmt.krw(-12000), '-₩12,000');
      expect(Fmt.signedKrw(9069), '+₩9,069');
      expect(Fmt.money(4850, 'JPY'), '¥4,850');
      expect(Fmt.money(12.5, 'USD'), r'$12.5');
      expect(Fmt.money(100, 'XYZ'), '100 XYZ');
    });

    test('D-day · 시간', () {
      expect(Fmt.dDay(7), 'D-7');
      expect(Fmt.dDay(0), 'D-DAY');
      expect(Fmt.dDay(-2), 'D+2');
      expect(Fmt.minutes(45), '45분');
      expect(Fmt.minutes(190), '3시간 10분');
      expect(Fmt.minutes(120), '2시간');
      expect(Fmt.shortDate(DateTime(2026, 10, 3)), '10.03 토');
    });
  });

  group('ExpenseDraft', () {
    ExpenseDraft draft(SplitMethod split, RateMode mode) => ExpenseDraft(
      payerMemberId: 'm1',
      title: '구로몬 시장',
      category: ExpenseCategory.food,
      paidDate: DateTime(2026, 10, 3),
      rateMode: mode,
      splitMethod: split,
      amountLocal: 4850,
      amountKrw: 12000,
      manualRate: 9.1,
      memberIds: ['m1', 'm2'],
      items: [
        ExpenseItemDraft(
          name: '라멘',
          amount: 1200,
          members: {'m1': 5000, 'm2': 7000},
        ),
      ],
    );

    test('균등 분담은 memberIds만 보내고 외화 금액을 쓴다', () {
      final json = draft(SplitMethod.equal, RateMode.api).toJson();
      expect(json['rateMode'], 'API');
      expect(json['amountLocal'], 4850);
      expect(json['amountKrw'], isNull);
      expect(json['manualRate'], isNull);
      expect(json['memberIds'], ['m1', 'm2']);
      expect(json['items'], isNull);
      expect(json['paidDate'], '2026-10-03');
    });

    test('원화 지출은 원화 금액만 보낸다', () {
      final json = draft(SplitMethod.custom, RateMode.krw).toJson();
      expect(json['amountLocal'], isNull);
      expect(json['amountKrw'], 12000);
      final members = (json['items'] as List).first['members'] as List;
      expect(members.first, {'memberId': 'm1', 'shareKrw': 5000});
    });

    test('항목별 분담은 항목 금액을 보내고 개인 금액은 보내지 않는다', () {
      final json = draft(SplitMethod.item, RateMode.manual).toJson();
      expect(json['manualRate'], 9.1);
      final item = (json['items'] as List).first as Map<String, dynamic>;
      expect(item['amountLocal'], 1200);
      expect((item['members'] as List).first, {
        'memberId': 'm1',
        'shareKrw': null,
      });
    });
  });
}
