import 'expense_repository.dart';
import 'expense_request.dart';
import 'expense_split_repository.dart';
import 'sample_expense_split_repository.dart';

/// Keeps previews for this app session; never sends a request to a server.
class MemoryExpenseRepository implements ExpenseRepository {
  MemoryExpenseRepository({this._trip});
  ExpenseTripContext? _trip;
  Future<void>? _initialization;
  final List<ExpenseRecord> _expenses = [];

  @override
  Future<ExpenseOverview> loadExpenses() async {
    await (_initialization ??= _seed());
    return ExpenseOverview(trip: _trip!, expenses: _expenses);
  }

  Future<void> _seed() async {
    if (_trip == null) {
      final sample = await const SampleExpenseSplitRepository().loadSplitData();
      _trip = ExpenseTripContext(
        tripName: sample.tripName,
        currentMemberId: sample.members.first.memberId,
        defaultDate: sample.paidDate,
        previewRate: sample.previewRate,
        members: sample.members,
      );
      _expenses.add(
        _sampleRecord('sample-ramen', sample, SplitMethod.item, 68816, [
          14305,
          14913,
          14306,
          14306,
          10986,
        ]),
      );
      final ticket = ExpenseSplitData(
        tripName: sample.tripName,
        title: '우메다 스카이빌딩 입장권',
        paidDate: '2026-11-02',
        payerMemberId: sample.members[1].memberId,
        previewRate: sample.previewRate,
        category: ExpenseCategory.activity,
        initialSplitMethod: SplitMethod.equal,
        members: sample.members,
        items: [
          ExpenseSplitItem(
            name: '입장권',
            quantity: 5,
            amountLocal: 10000,
            memberIds: sample.members.map((member) => member.memberId).toSet(),
          ),
        ],
      );
      _expenses.add(
        _sampleRecord('sample-ticket', ticket, SplitMethod.equal, 93500, [
          18700,
          18700,
          18700,
          18700,
          18700,
        ]),
      );
    }
  }

  ExpenseRecord _sampleRecord(
    String id,
    ExpenseSplitData data,
    SplitMethod method,
    int total,
    List<int> shares,
  ) => ExpenseRecord(
    id: id,
    data: data,
    request: ExpenseRequest(
      payerMemberId: data.payerMemberId,
      title: data.title,
      category: data.category,
      paidDate: data.paidDate,
      rateMode: RateMode.manual,
      manualRate: data.previewRate,
      amountLocal: data.items.fold<num>(
        0,
        (sum, item) => sum + item.amountLocal,
      ),
      splitMethod: method,
      items: data.items
          .map(
            (item) => ExpenseRequestItem(
              name: item.name,
              amountLocal: item.amountLocal,
              members: item.memberIds
                  .map((id) => ExpenseRequestMember(memberId: id))
                  .toList(),
            ),
          )
          .toList(),
    ),
    amountKrw: total,
    sharesKrw: {
      for (var i = 0; i < data.members.length; i++)
        data.members[i].memberId: shares[i],
    },
  );

  @override
  Future<ExpenseRecord> saveExpense(ExpenseRecord expense) async {
    final index = _expenses.indexWhere((item) => item.id == expense.id);
    if (index < 0) {
      _expenses.add(expense);
    } else {
      _expenses[index] = expense;
    }
    return expense;
  }
}
