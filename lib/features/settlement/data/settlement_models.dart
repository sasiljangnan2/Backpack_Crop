const int maxSettlementWon = 9007199254740991;

int _won(Object? value, {bool hasSign = false}) {
  if (value is! int ||
      value.abs() > maxSettlementWon ||
      (!hasSign && value < 0)) {
    throw const FormatException('Invalid KRW amount');
  }
  return value;
}

class SettlementPerson {
  const SettlementPerson({required this.memberId, required this.name});
  final String memberId, name;
  factory SettlementPerson.fromJson(Map<String, Object?> json) =>
      SettlementPerson(
        memberId: json['memberId'] as String,
        name: json['name'] as String,
      );
  Map<String, Object?> toJson() => {'memberId': memberId, 'name': name};
}

class SettlementMember {
  const SettlementMember({
    required this.person,
    required this.paidKrw,
    required this.shareKrw,
    required this.balanceKrw,
  });
  final SettlementPerson person;
  final int paidKrw, shareKrw, balanceKrw;
  factory SettlementMember.fromJson(Map<String, Object?> json) =>
      SettlementMember(
        person: SettlementPerson.fromJson(json),
        paidKrw: _won(json['paidKrw']),
        shareKrw: _won(json['shareKrw']),
        balanceKrw: _won(json['balanceKrw'], hasSign: true),
      );
  Map<String, Object?> toJson() => {
    ...person.toJson(),
    'paidKrw': paidKrw,
    'shareKrw': shareKrw,
    'balanceKrw': balanceKrw,
  };
}

class SettlementTransfer {
  const SettlementTransfer({
    required this.from,
    required this.to,
    required this.amountKrw,
  });
  final SettlementPerson from, to;
  final int amountKrw;
  bool involves(String id) => from.memberId == id || to.memberId == id;
  factory SettlementTransfer.fromJson(Map<String, Object?> json) =>
      SettlementTransfer(
        from: SettlementPerson.fromJson(json['from'] as Map<String, Object?>),
        to: SettlementPerson.fromJson(json['to'] as Map<String, Object?>),
        amountKrw: _won(json['amountKrw']),
      );
  Map<String, Object?> toJson() => {
    'from': from.toJson(),
    'to': to.toJson(),
    'amountKrw': amountKrw,
  };
}

class SettlementSnapshot {
  SettlementSnapshot({
    required this.totalKrw,
    required List<SettlementMember> members,
    required List<SettlementTransfer> transfers,
  }) : members = List.unmodifiable(members),
       transfers = List.unmodifiable(transfers) {
    _validate();
  }
  final int totalKrw;
  final List<SettlementMember> members;
  final List<SettlementTransfer> transfers;
  SettlementMember? member(String id) {
    for (final item in members) {
      if (item.person.memberId == id) {
        return item;
      }
    }
    return null;
  }

  List<SettlementTransfer> transfersFor(String id) =>
      List.unmodifiable(transfers.where((item) => item.involves(id)));
  factory SettlementSnapshot.fromJson(Map<String, Object?> json) =>
      SettlementSnapshot(
        totalKrw: _won(json['totalKrw']),
        members: (json['members'] as List<Object?>)
            .map(
              (item) => SettlementMember.fromJson(item as Map<String, Object?>),
            )
            .toList(),
        transfers: (json['transfers'] as List<Object?>)
            .map(
              (item) =>
                  SettlementTransfer.fromJson(item as Map<String, Object?>),
            )
            .toList(),
      );
  Map<String, Object?> toJson() => {
    'totalKrw': totalKrw,
    'members': members.map((item) => item.toJson()).toList(),
    'transfers': transfers.map((item) => item.toJson()).toList(),
  };

  // Reject inconsistent responses instead of silently showing an incorrect debt.
  void _validate() {
    _won(totalKrw);
    final byId = <String, SettlementMember>{};
    var paid = BigInt.zero, share = BigInt.zero;
    for (final item in members) {
      final id = item.person.memberId;
      if (id.isEmpty ||
          byId.containsKey(id) ||
          item.person.name.trim().isEmpty) {
        throw const FormatException('Invalid settlement member');
      }
      _won(item.paidKrw);
      _won(item.shareKrw);
      _won(item.balanceKrw, hasSign: true);
      if (item.balanceKrw != item.paidKrw - item.shareKrw) {
        throw const FormatException('Invalid member balance');
      }
      byId[id] = item;
      paid += BigInt.from(item.paidKrw);
      share += BigInt.from(item.shareKrw);
    }
    if (paid != BigInt.from(totalKrw) || share != BigInt.from(totalKrw)) {
      throw const FormatException('Invalid settlement total');
    }
    final net = {for (final id in byId.keys) id: BigInt.zero};
    for (final item in transfers) {
      _won(item.amountKrw);
      if (item.amountKrw == 0 ||
          item.from.memberId == item.to.memberId ||
          !byId.containsKey(item.from.memberId) ||
          !byId.containsKey(item.to.memberId)) {
        throw const FormatException('Invalid transfer');
      }
      net[item.from.memberId] =
          net[item.from.memberId]! - BigInt.from(item.amountKrw);
      net[item.to.memberId] =
          net[item.to.memberId]! + BigInt.from(item.amountKrw);
    }
    for (final item in members) {
      if (net[item.person.memberId] != BigInt.from(item.balanceKrw)) {
        throw const FormatException('Unbalanced transfer amounts');
      }
    }
  }
}
