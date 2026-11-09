import '../../../core/network/json.dart';
import '../../expense/data/expense_models.dart';
import '../../trip/data/trip_models.dart';

enum SettlementStatus { receive, send, settled }

enum TransferDirection { send, receive }

class SettlementMember {
  const SettlementMember({
    required this.memberId,
    required this.name,
    required this.isMe,
    required this.hasLeft,
    required this.paidKrw,
    required this.shareKrw,
    required this.balanceKrw,
    required this.status,
  });

  factory SettlementMember.fromJson(Json json) => SettlementMember(
    memberId: json['memberId'] as String,
    name: json['name'] as String,
    isMe: json['isMe'] as bool? ?? false,
    hasLeft: json['hasLeft'] as bool? ?? false,
    paidKrw: integer(json['paidKrw']),
    shareKrw: integer(json['shareKrw']),
    balanceKrw: integer(json['balanceKrw']),
    status: enumOf(
      SettlementStatus.values,
      json['status'],
      SettlementStatus.settled,
    ),
  );

  final String memberId;
  final String name;
  final bool isMe;
  final bool hasLeft;
  final int paidKrw;
  final int shareKrw;
  final int balanceKrw;
  final SettlementStatus status;
}

class Transfer {
  const Transfer({
    required this.from,
    required this.to,
    required this.amountKrw,
  });

  factory Transfer.fromJson(Json json) => Transfer(
    from: MemberRef.fromJson(json['from'] as Json),
    to: MemberRef.fromJson(json['to'] as Json),
    amountKrw: integer(json['amountKrw']),
  );

  final MemberRef from;
  final MemberRef to;
  final int amountKrw;
}

class Settlement {
  const Settlement({
    required this.totalKrw,
    required this.expenseCount,
    required this.transferTotalKrw,
    required this.directTransferCount,
    required this.members,
    required this.transfers,
  });

  factory Settlement.fromJson(Json json) => Settlement(
    totalKrw: integer(json['totalKrw']),
    expenseCount: integer(json['expenseCount']),
    transferTotalKrw: integer(json['transferTotalKrw']),
    directTransferCount: integerOrNull(json['directTransferCount']) ?? 0,
    members: list(json['members'], SettlementMember.fromJson),
    transfers: list(json['transfers'], Transfer.fromJson),
  );

  final int totalKrw;
  final int expenseCount;
  final int transferTotalKrw;

  /// 지출마다 결제자에게 바로 보낸다면 필요한 송금 건수 (최소화 전)
  final int directTransferCount;
  final List<SettlementMember> members;
  final List<Transfer> transfers;
}

class MyTransfer {
  const MyTransfer({
    required this.direction,
    required this.counterpart,
    required this.amountKrw,
  });

  factory MyTransfer.fromJson(Json json) => MyTransfer(
    direction: enumOf(
      TransferDirection.values,
      json['direction'],
      TransferDirection.send,
    ),
    counterpart: MemberRef.fromJson(json['counterpart'] as Json),
    amountKrw: integer(json['amountKrw']),
  );

  final TransferDirection direction;
  final MemberRef counterpart;
  final int amountKrw;
}

class ExpenseLine {
  const ExpenseLine({
    required this.expenseId,
    required this.title,
    required this.category,
    required this.paidDate,
    required this.amountKrw,
    required this.payer,
    required this.isPaidByMe,
    required this.paidKrw,
    required this.myShareKrw,
    required this.balanceKrw,
  });

  factory ExpenseLine.fromJson(Json json) => ExpenseLine(
    expenseId: json['expenseId'] as String,
    title: json['title'] as String,
    category: enumOf(
      ExpenseCategory.values,
      json['category'],
      ExpenseCategory.etc,
    ),
    paidDate: date(json['paidDate']),
    amountKrw: integer(json['amountKrw']),
    payer: MemberRef.fromJson(json['payer'] as Json),
    isPaidByMe: json['isPaidByMe'] as bool? ?? false,
    paidKrw: integer(json['paidKrw']),
    myShareKrw: integer(json['myShareKrw']),
    balanceKrw: integer(json['balanceKrw']),
  );

  final String expenseId;
  final String title;
  final ExpenseCategory category;
  final DateTime paidDate;
  final int amountKrw;
  final MemberRef payer;
  final bool isPaidByMe;
  final int paidKrw;
  final int myShareKrw;
  final int balanceKrw;
}

class MySettlement {
  const MySettlement({
    required this.me,
    required this.paidKrw,
    required this.shareKrw,
    required this.balanceKrw,
    required this.status,
    required this.tripTotalKrw,
    required this.expenseCount,
    required this.transfers,
    required this.expenses,
  });

  factory MySettlement.fromJson(Json json) => MySettlement(
    me: MemberRef.fromJson(json['me'] as Json),
    paidKrw: integer(json['paidKrw']),
    shareKrw: integer(json['shareKrw']),
    balanceKrw: integer(json['balanceKrw']),
    status: enumOf(
      SettlementStatus.values,
      json['status'],
      SettlementStatus.settled,
    ),
    tripTotalKrw: integer(json['tripTotalKrw']),
    expenseCount: integer(json['expenseCount']),
    transfers: list(json['transfers'], MyTransfer.fromJson),
    expenses: list(json['expenses'], ExpenseLine.fromJson),
  );

  final MemberRef me;
  final int paidKrw;
  final int shareKrw;
  final int balanceKrw;
  final SettlementStatus status;
  final int tripTotalKrw;
  final int expenseCount;
  final List<MyTransfer> transfers;
  final List<ExpenseLine> expenses;
}

class SettlementShareSummary {
  const SettlementShareSummary({
    required this.id,
    required this.sharedBy,
    required this.createdAt,
    required this.transferCount,
    required this.transferTotalKrw,
  });

  factory SettlementShareSummary.fromJson(Json json) => SettlementShareSummary(
    id: json['id'] as String,
    sharedBy: MemberRef.fromJson(json['sharedBy'] as Json),
    createdAt: instant(json['createdAt']),
    transferCount: integer(json['transferCount']),
    transferTotalKrw: integer(json['transferTotalKrw']),
  );

  final String id;
  final MemberRef sharedBy;
  final DateTime createdAt;
  final int transferCount;
  final int transferTotalKrw;
}

class SettlementShare {
  const SettlementShare({
    required this.id,
    required this.sharedBy,
    required this.createdAt,
    required this.transferTotalKrw,
    required this.transfers,
  });

  factory SettlementShare.fromJson(Json json) => SettlementShare(
    id: json['id'] as String,
    sharedBy: MemberRef.fromJson(json['sharedBy'] as Json),
    createdAt: instant(json['createdAt']),
    transferTotalKrw: integer(json['transferTotalKrw']),
    transfers: list(json['transfers'], Transfer.fromJson),
  );

  final String id;
  final MemberRef sharedBy;
  final DateTime createdAt;
  final int transferTotalKrw;
  final List<Transfer> transfers;
}

class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.category,
    required this.name,
    required this.amount,
    required this.currencyCode,
    required this.amountKrw,
  });

  factory BudgetItem.fromJson(Json json) => BudgetItem(
    id: json['id'] as String,
    category: enumOf(
      ExpenseCategory.values,
      json['category'],
      ExpenseCategory.etc,
    ),
    name: json['name'] as String,
    amount: decimal(json['amount']),
    currencyCode: json['currencyCode'] as String,
    amountKrw: integerOrNull(json['amountKrw']),
  );

  final String id;
  final ExpenseCategory category;
  final String name;
  final double amount;
  final String currencyCode;
  final int? amountKrw;
}

class CategoryBudget {
  const CategoryBudget({
    required this.category,
    required this.budgetKrw,
    required this.spentKrw,
  });

  factory CategoryBudget.fromJson(Json json) => CategoryBudget(
    category: enumOf(
      ExpenseCategory.values,
      json['category'],
      ExpenseCategory.etc,
    ),
    budgetKrw: integer(json['budgetKrw']),
    spentKrw: integer(json['spentKrw']),
  );

  final ExpenseCategory category;
  final int budgetKrw;
  final int spentKrw;
}

class Budget {
  const Budget({
    required this.items,
    required this.summary,
    required this.totalBudgetKrw,
    required this.totalSpentKrw,
    required this.memberCount,
    required this.perPersonBudgetKrw,
    required this.currencyCode,
    required this.todayRate,
    required this.hasUnconvertedItems,
  });

  factory Budget.fromJson(Json json) => Budget(
    items: list(json['items'], BudgetItem.fromJson),
    summary: list(json['summary'], CategoryBudget.fromJson),
    totalBudgetKrw: integer(json['totalBudgetKrw']),
    totalSpentKrw: integer(json['totalSpentKrw']),
    memberCount: integer(json['memberCount']),
    perPersonBudgetKrw: integer(json['perPersonBudgetKrw']),
    currencyCode: json['currencyCode'] as String,
    todayRate: ExchangeRate.fromJsonOrNull(json['todayRate']),
    hasUnconvertedItems: json['hasUnconvertedItems'] as bool? ?? false,
  );

  final List<BudgetItem> items;
  final List<CategoryBudget> summary;
  final int totalBudgetKrw;
  final int totalSpentKrw;
  final int memberCount;
  final int perPersonBudgetKrw;
  final String currencyCode;
  final ExchangeRate? todayRate;
  final bool hasUnconvertedItems;

  /// 예산 대비 사용률 (예산이 없으면 null)
  double? get usedRatio =>
      totalBudgetKrw == 0 ? null : totalSpentKrw / totalBudgetKrw;
}
