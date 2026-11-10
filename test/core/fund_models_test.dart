import 'package:backpack/features/expense/data/expense_models.dart';
import 'package:backpack/features/settlement/data/settlement_models.dart';
import 'package:backpack/features/trip/data/trip_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _fundRef = {'memberId': MemberRef.fundId, 'name': '공금'};
const _me = {'memberId': 'm1', 'name': '재윤'};

void main() {
  test('공금 현황을 읽고 금액 · 메모 · 수정 권한을 그대로 담는다', () {
    final fund = Fund.fromJson({
      'collectedKrw': 300000,
      'spentKrw': 90000,
      'remainingKrw': 210000,
      'members': [
        {'member': _me, 'contributedKrw': 150000},
      ],
      'contributions': [
        {
          'id': 'c1',
          'member': _me,
          'amountKrw': 150000,
          'contributedOn': '2026-09-20',
          'memo': null,
          'creator': _me,
          'canEdit': true,
        },
      ],
    });

    expect(fund.remainingKrw, 210000);
    expect(fund.members.single.contributedKrw, 150000);
    expect(fund.contributions.single.memo, isNull);
    expect(fund.contributions.single.canEdit, isTrue);
    expect(fund.contributions.single.contributedOn, DateTime(2026, 9, 20));
  });

  test('공금 멤버는 고정 id로 알아본다', () {
    expect(MemberRef.fromJson(_fundRef).isFund, isTrue);
    expect(MemberRef.fromJson(_me).isFund, isFalse);
  });

  test('공금 지출은 입력한 사람이 달라도 대리 입력으로 치지 않는다', () {
    ExpenseListItem item(bool fromFund) => ExpenseListItem.fromJson({
      'id': 'e1',
      'title': '저녁',
      'category': 'FOOD',
      'paidDate': '2026-10-03',
      'rateMode': 'KRW',
      'amountKrw': 30000,
      'payer': fromFund ? _fundRef : const {'memberId': 'm2', 'name': '준'},
      'paidFromFund': fromFund,
      'creator': _me,
      'isPaidByMe': false,
      'myShareKrw': 10000,
    });

    expect(item(true).paidFromFund, isTrue);
    expect(item(true).isProxy, isFalse);
    expect(item(false).isProxy, isTrue);
  });

  test('지출 요청에 공금 여부와 이어진 일정을 담는다', () {
    final json = ExpenseDraft(
      payerMemberId: 'm1',
      paidFromFund: true,
      scheduleId: 's1',
      title: '저녁',
      category: ExpenseCategory.food,
      paidDate: DateTime(2026, 10, 3),
      rateMode: RateMode.krw,
      splitMethod: SplitMethod.equal,
      amountKrw: 30000,
    ).toJson();

    expect(json['paidFromFund'], isTrue);
    expect(json['scheduleId'], 's1');
    expect(json['payerMemberId'], 'm1');
  });

  test('공금을 쓰지 않은 정산은 fund가 없고 모은 돈은 0이다', () {
    final settlement = Settlement.fromJson({
      'totalKrw': 0,
      'expenseCount': 0,
      'transferTotalKrw': 0,
      'directTransferCount': 0,
      'members': [
        {
          'memberId': 'm1',
          'name': '재윤',
          'isMe': true,
          'hasLeft': false,
          'paidKrw': 0,
          'shareKrw': 0,
          'balanceKrw': 0,
          'status': 'SETTLED',
        },
      ],
      'transfers': <Object>[],
      'fund': null,
    });

    expect(settlement.fund, isNull);
    expect(settlement.members.single.contributedKrw, 0);
  });

  test('공금이 없는 예전 서버의 예산 응답도 빈 공금으로 읽는다', () {
    final budget = Budget.fromJson({
      'items': <Object>[],
      'summary': <Object>[],
      'totalBudgetKrw': 300000,
      'totalSpentKrw': 0,
      'memberCount': 2,
      'perPersonBudgetKrw': 150000,
      'currencyCode': 'JPY',
      'todayRate': null,
    });

    expect(budget.fund.collectedKrw, 0);
    expect(budget.fund.contributions, isEmpty);
    expect(budget.remainingBudgetKrw, 300000);
  });
}
