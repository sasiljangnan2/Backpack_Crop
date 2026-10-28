import '../../expense/data/expense_repository.dart';
import 'settlement_models.dart';
import 'settlement_repository.dart';

/// Recomputes a session-only preview from the shared expense repository.
class PreviewSettlementRepository implements SettlementRepository {
  const PreviewSettlementRepository(this.expenses);
  final ExpenseRepository expenses;
  @override
  Future<SettlementSnapshot> load() async =>
      previewSettlement(await expenses.loadExpenses());
}

/// Greedy transfers illustrate balances; the server owns actual optimization.
SettlementSnapshot previewSettlement(ExpenseOverview overview) {
  final ids = overview.trip.members.map((member) => member.memberId).toSet();
  if (ids.length != overview.trip.members.length) {
    throw const FormatException('Duplicate preview members');
  }
  final paid = {for (final id in ids) id: 0};
  final shares = {for (final id in ids) id: 0};
  var total = 0;
  int addWon(int left, int right) {
    if (right < 0 ||
        right > maxSettlementWon ||
        left > maxSettlementWon - right) {
      throw const FormatException('Invalid preview amount');
    }
    return left + right;
  }

  for (final expense in overview.expenses) {
    final payer = expense.request.payerMemberId;
    if (!ids.contains(payer) || !ids.containsAll(expense.sharesKrw.keys)) {
      throw const FormatException('Unknown preview member');
    }
    var burden = 0;
    for (final entry in expense.sharesKrw.entries) {
      burden = addWon(burden, entry.value);
      shares[entry.key] = addWon(shares[entry.key]!, entry.value);
    }
    if (burden != expense.amountKrw) {
      throw const FormatException('Unbalanced preview expense');
    }
    total = addWon(total, expense.amountKrw);
    paid[payer] = addWon(paid[payer]!, expense.amountKrw);
  }
  final members = overview.trip.members
      .map(
        (item) => SettlementMember(
          person: SettlementPerson(memberId: item.memberId, name: item.name),
          paidKrw: paid[item.memberId]!,
          shareKrw: shares[item.memberId]!,
          balanceKrw: paid[item.memberId]! - shares[item.memberId]!,
        ),
      )
      .toList();
  List<SettlementMember> sorted(bool isCreditor) =>
      members
          .where(
            (item) => isCreditor ? item.balanceKrw > 0 : item.balanceKrw < 0,
          )
          .toList()
        ..sort((a, b) {
          final amount = b.balanceKrw.abs().compareTo(a.balanceKrw.abs());
          return amount != 0
              ? amount
              : a.person.memberId.compareTo(b.person.memberId);
        });
  final creditors = sorted(true), debtors = sorted(false);
  final remaining = {
    for (final item in members) item.person.memberId: item.balanceKrw.abs(),
  };
  final transfers = <SettlementTransfer>[];
  var from = 0, to = 0;
  while (from < debtors.length && to < creditors.length) {
    final debtor = debtors[from].person, creditor = creditors[to].person;
    final debt = remaining[debtor.memberId]!,
        credit = remaining[creditor.memberId]!;
    final amount = debt < credit ? debt : credit;
    transfers.add(
      SettlementTransfer(from: debtor, to: creditor, amountKrw: amount),
    );
    remaining[debtor.memberId] = debt - amount;
    remaining[creditor.memberId] = credit - amount;
    if (debt == amount) {
      from++;
    }
    if (credit == amount) {
      to++;
    }
  }
  return SettlementSnapshot(
    totalKrw: total,
    members: members,
    transfers: transfers,
  );
}
