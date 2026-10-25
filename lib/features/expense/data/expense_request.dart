enum ExpenseCategory { food, lodging, transport, activity, shopping, etc }

enum RateMode { api, prepaid, manual, krw }

enum SplitMethod { equal, item, custom }

/// Request fields follow docs/api/README.md, section 9.
class ExpenseRequest {
  ExpenseRequest({
    required this.payerMemberId,
    required this.title,
    required this.category,
    required this.paidDate,
    required this.rateMode,
    required this.splitMethod,
    required List<ExpenseRequestItem> items,
    this.amountLocal,
    this.manualRate,
    this.amountKrw,
  }) : items = List.unmodifiable(items);

  final String payerMemberId;
  final String title;
  final ExpenseCategory category;
  // A calendar date must not be converted to UTC.
  final String paidDate;
  final RateMode rateMode;
  final num? amountLocal;
  final num? manualRate;
  final int? amountKrw;
  final SplitMethod splitMethod;
  final List<ExpenseRequestItem> items;

  factory ExpenseRequest.fromJson(Map<String, Object?> json) => ExpenseRequest(
    payerMemberId: json['payerMemberId'] as String,
    title: json['title'] as String,
    category: ExpenseCategory.values.byName(
      (json['category'] as String).toLowerCase(),
    ),
    paidDate: json['paidDate'] as String,
    rateMode: RateMode.values.byName(
      (json['rateMode'] as String).toLowerCase(),
    ),
    amountLocal: json['amountLocal'] as num?,
    manualRate: json['manualRate'] as num?,
    amountKrw: (json['amountKrw'] as num?)?.toInt(),
    splitMethod: SplitMethod.values.byName(
      (json['splitMethod'] as String).toLowerCase(),
    ),
    items: (json['items'] as List<Object?>)
        .map(
          (item) => ExpenseRequestItem.fromJson(item as Map<String, Object?>),
        )
        .toList(),
  );

  Map<String, Object?> toJson() => {
    'payerMemberId': payerMemberId,
    'title': title,
    'category': category.name.toUpperCase(),
    'paidDate': paidDate,
    'rateMode': rateMode.name.toUpperCase(),
    'amountLocal': amountLocal,
    'manualRate': manualRate,
    'amountKrw': amountKrw,
    'splitMethod': splitMethod.name.toUpperCase(),
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class ExpenseRequestItem {
  ExpenseRequestItem({
    required this.name,
    required List<ExpenseRequestMember> members,
    this.amountLocal,
    this.amountKrw,
  }) : members = List.unmodifiable(members);

  final String name;
  final num? amountLocal;
  final int? amountKrw;
  final List<ExpenseRequestMember> members;

  factory ExpenseRequestItem.fromJson(Map<String, Object?> json) =>
      ExpenseRequestItem(
        name: json['name'] as String,
        amountLocal: json['amountLocal'] as num?,
        amountKrw: (json['amountKrw'] as num?)?.toInt(),
        members: (json['members'] as List<Object?>)
            .map(
              (member) =>
                  ExpenseRequestMember.fromJson(member as Map<String, Object?>),
            )
            .toList(),
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'amountLocal': amountLocal,
    'amountKrw': amountKrw,
    'members': members.map((member) => member.toJson()).toList(),
  };
}

class ExpenseRequestMember {
  const ExpenseRequestMember({required this.memberId, this.shareKrw});

  final String memberId;
  final int? shareKrw;

  factory ExpenseRequestMember.fromJson(Map<String, Object?> json) =>
      ExpenseRequestMember(
        memberId: json['memberId'] as String,
        shareKrw: (json['shareKrw'] as num?)?.toInt(),
      );

  Map<String, Object?> toJson() => {
    'memberId': memberId,
    if (shareKrw != null) 'shareKrw': shareKrw,
  };
}
