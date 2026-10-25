import 'expense_request.dart';
import 'expense_split_repository.dart';

class ExpenseTripContext {
  ExpenseTripContext({
    required this.tripName,
    required this.currentMemberId,
    required this.defaultDate,
    required this.previewRate,
    required List<ExpenseSplitMember> members,
    this.currencyCode = 'JPY',
    this.budgetKrw = 2000000,
  }) : members = List.unmodifiable(members);

  final String tripName;
  final String currentMemberId;
  final String defaultDate;
  final num previewRate;
  final List<ExpenseSplitMember> members;
  final String currencyCode;
  final int budgetKrw;
}

/// An in-memory view snapshot. API request fields remain in ExpenseRequest.
class ExpenseRecord {
  ExpenseRecord({
    required this.id,
    required this.data,
    required this.request,
    required this.amountKrw,
    required Map<String, int> sharesKrw,
  }) : sharesKrw = Map.unmodifiable(sharesKrw);

  final String id;
  final ExpenseSplitData data;
  final ExpenseRequest request;
  final int amountKrw;
  final Map<String, int> sharesKrw;

  String get payerName => data.members
      .firstWhere((member) => member.memberId == request.payerMemberId)
      .name;
}

class ExpenseOverview {
  ExpenseOverview({required this.trip, required List<ExpenseRecord> expenses})
    : expenses = List.unmodifiable(expenses);

  final ExpenseTripContext trip;
  final List<ExpenseRecord> expenses;
}

abstract interface class ExpenseRepository {
  Future<ExpenseOverview> loadExpenses();
  Future<ExpenseRecord> saveExpense(ExpenseRecord expense);
}
