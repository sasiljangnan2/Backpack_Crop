import 'package:backpack/core/network/api_exception.dart';
import 'package:backpack/features/expense/data/expense_repository.dart';
import 'package:backpack/features/expense/data/expense_request.dart';
import 'package:backpack/features/expense/data/expense_split_repository.dart';
import 'package:backpack/features/settlement/data/settlement_models.dart';
import 'package:backpack/features/settlement/data/settlement_repository.dart';

SettlementSnapshot settlementFixture({
  bool isBalanced = false,
  bool isEmpty = false,
  bool hasLongNames = false,
  int multiplier = 1,
}) {
  final people = [
    for (final id in ['a', 'b', 'c', 'd'])
      SettlementPerson(
        memberId: id,
        name: hasLongNames
            ? '아주 긴 이름을 가진 여행 동행 $id'
            : id == 'a'
            ? '여행자'
            : '동행 $id',
      ),
  ];
  final paid = isEmpty
      ? [0, 0, 0, 0]
      : isBalanced
      ? [6000, 6000, 6000, 6000]
      : [10000, 2000, 10000, 2000];
  return SettlementSnapshot(
    totalKrw: (isEmpty ? 0 : 24000) * multiplier,
    members: [
      for (var i = 0; i < people.length; i++)
        SettlementMember(
          person: people[i],
          paidKrw: paid[i] * multiplier,
          shareKrw: (isEmpty ? 0 : 6000) * multiplier,
          balanceKrw: (paid[i] - (isEmpty ? 0 : 6000)) * multiplier,
        ),
    ],
    transfers: isEmpty || isBalanced
        ? []
        : [
            SettlementTransfer(
              from: people[1],
              to: people[0],
              amountKrw: 4000 * multiplier,
            ),
            SettlementTransfer(
              from: people[3],
              to: people[2],
              amountKrw: 4000 * multiplier,
            ),
          ],
  );
}

class FixtureSettlementRepository implements SettlementRepository {
  FixtureSettlementRepository(this.result);
  SettlementSnapshot result;
  bool hasError = false;
  int calls = 0;
  @override
  Future<SettlementSnapshot> load() async {
    calls++;
    if (hasError) {
      throw const ApiException.network();
    }
    return result;
  }
}

ExpenseTripContext settlementExpenseTrip() => ExpenseTripContext(
  tripName: '함께하는 여행',
  currentMemberId: 'a',
  defaultDate: '2026-11-01',
  previewRate: 1,
  currencyCode: 'KRW',
  members: const [
    ExpenseSplitMember(memberId: 'a', name: '여행자'),
    ExpenseSplitMember(memberId: 'b', name: '동행'),
  ],
);

ExpenseRecord settlementExpense({int amount = 12000, String id = 'expense-a'}) {
  final trip = settlementExpenseTrip();
  final data = ExpenseSplitData(
    tripName: trip.tripName,
    title: '함께한 점심',
    paidDate: trip.defaultDate,
    payerMemberId: 'a',
    previewRate: 1,
    currencyCode: 'KRW',
    members: trip.members,
    items: [
      ExpenseSplitItem(
        name: '점심',
        quantity: 1,
        amountLocal: amount,
        memberIds: {'a', 'b'},
      ),
    ],
  );
  return ExpenseRecord(
    id: id,
    data: data,
    request: ExpenseRequest(
      payerMemberId: 'a',
      title: data.title,
      category: ExpenseCategory.food,
      paidDate: data.paidDate,
      rateMode: RateMode.krw,
      splitMethod: SplitMethod.equal,
      amountKrw: amount,
      items: [
        ExpenseRequestItem(
          name: '점심',
          amountKrw: amount,
          members: const [
            ExpenseRequestMember(memberId: 'a'),
            ExpenseRequestMember(memberId: 'b'),
          ],
        ),
      ],
    ),
    amountKrw: amount,
    sharesKrw: {'a': amount ~/ 2, 'b': amount - amount ~/ 2},
  );
}
