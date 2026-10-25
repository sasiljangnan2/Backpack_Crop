import 'expense_request.dart';

class ExpenseSplitMember {
  const ExpenseSplitMember({required this.memberId, required this.name});

  final String memberId;
  final String name;
}

class ExpenseSplitItem {
  ExpenseSplitItem({
    required this.name,
    required this.quantity,
    required this.amountLocal,
    required Set<String> memberIds,
  }) : memberIds = Set.unmodifiable(memberIds);

  final String name;
  // Quantity is display information; amountLocal is the entire item amount.
  final int quantity;
  final num amountLocal;
  final Set<String> memberIds;

  ExpenseSplitItem withMembers(Set<String> ids) => ExpenseSplitItem(
    name: name,
    quantity: quantity,
    amountLocal: amountLocal,
    memberIds: ids,
  );
}

/// Data needed by the editor, not an invented API response schema.
class ExpenseSplitData {
  ExpenseSplitData({
    required this.tripName,
    required this.title,
    required this.paidDate,
    required this.payerMemberId,
    required this.previewRate,
    this.category = ExpenseCategory.food,
    this.currencyCode = 'JPY',
    this.initialSplitMethod = SplitMethod.item,
    required List<ExpenseSplitMember> members,
    required List<ExpenseSplitItem> items,
  }) : members = List.unmodifiable(members),
       items = List.unmodifiable(items);

  final String tripName;
  final String title;
  final String paidDate;
  final String payerMemberId;
  final num previewRate;
  final ExpenseCategory category;
  final String currencyCode;
  final SplitMethod initialSplitMethod;
  final List<ExpenseSplitMember> members;
  final List<ExpenseSplitItem> items;
}

abstract interface class ExpenseSplitRepository {
  Future<ExpenseSplitData> loadSplitData();
}

class DraftExpenseSplitRepository implements ExpenseSplitRepository {
  const DraftExpenseSplitRepository(this.data);
  final ExpenseSplitData data;

  @override
  Future<ExpenseSplitData> loadSplitData() async => data;
}
