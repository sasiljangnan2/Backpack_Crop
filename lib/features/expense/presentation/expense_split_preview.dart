import '../data/expense_split_repository.dart';

class ExpenseSplitPreview {
  ExpenseSplitPreview({
    required this.totalLocal,
    required this.totalWon,
    required List<num> localAmounts,
    required List<int> amountsWon,
    required List<int> adjustments,
  }) : localAmounts = List.unmodifiable(localAmounts),
       amountsWon = List.unmodifiable(amountsWon),
       adjustments = List.unmodifiable(adjustments);

  final num totalLocal;
  final int totalWon;
  final List<num> localAmounts;
  final List<int> amountsWon;
  final List<int> adjustments;
}

/// UI preview only. Saved amounts and settlement are calculated by the server.
ExpenseSplitPreview? calculateSplitPreview(
  List<ExpenseSplitItem> items, {
  required List<ExpenseSplitMember> members,
  required String payerMemberId,
  required num rate,
  bool isEqual = false,
}) {
  final ids = members.map((member) => member.memberId).toSet();
  if (members.isEmpty ||
      ids.length != members.length ||
      !ids.contains(payerMemberId) ||
      !rate.isFinite ||
      rate <= 0 ||
      items.isEmpty ||
      items.any(
        (item) =>
            !item.amountLocal.isFinite ||
            item.amountLocal < 0 ||
            (!isEqual &&
                (item.memberIds.isEmpty || !ids.containsAll(item.memberIds))),
      )) {
    return null;
  }

  // Integer cents and a shared denominator avoid early per-item rounding.
  var scale = BigInt.one;
  for (final item in items) {
    final count = isEqual ? members.length : item.memberIds.length;
    final divisor = BigInt.from(count);
    scale = scale ~/ scale.gcd(divisor) * divisor;
  }
  final units = List.filled(members.length, BigInt.zero);
  var totalCents = 0;
  for (final item in items) {
    final cents = (item.amountLocal * 100).round();
    totalCents += cents;
    final selected = isEqual ? ids : item.memberIds;
    for (var i = 0; i < members.length; i++) {
      if (selected.contains(members[i].memberId)) {
        units[i] += BigInt.from(cents) * scale ~/ BigInt.from(selected.length);
      }
    }
  }
  final rateUnits = BigInt.from((rate * 1000000).round());
  final denominator = scale * BigInt.from(100000000);
  final totalWon =
      ((BigInt.from(totalCents) * rateUnits + BigInt.from(50000000)) ~/
              BigInt.from(100000000))
          .toInt();
  final amounts = units
      .map(
        (value) =>
            ((value * rateUnits + denominator ~/ BigInt.two) ~/ denominator)
                .toInt(),
      )
      .toList();
  final adjustments = List.filled(members.length, 0);
  var remainder = totalWon - amounts.fold<int>(0, (sum, value) => sum + value);
  final payer = members.indexWhere(
    (member) => member.memberId == payerMemberId,
  );
  if (amounts[payer] + remainder >= 0) {
    amounts[payer] += remainder;
    adjustments[payer] = remainder;
  } else {
    // A non-consuming payer cannot have a negative preview burden.
    for (var i = 0; i < amounts.length && remainder < 0; i++) {
      if (amounts[i] > 0) {
        amounts[i]--;
        adjustments[i]--;
        remainder++;
      }
    }
  }
  return ExpenseSplitPreview(
    totalLocal: totalCents / 100,
    totalWon: totalWon,
    localAmounts: units
        .map((value) => value.toDouble() / (scale.toDouble() * 100))
        .toList(),
    amountsWon: amounts,
    adjustments: adjustments,
  );
}
