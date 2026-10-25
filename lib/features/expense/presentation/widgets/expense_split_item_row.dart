import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../expense_split_strings.dart';
import '../../data/expense_split_repository.dart';

class ExpenseSplitItemRow extends StatelessWidget {
  const ExpenseSplitItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.members,
    required this.isEqual,
    required this.onSelected,
    this.currencyCode = 'JPY',
  });

  final int index;
  final String currencyCode;
  final ExpenseSplitItem item;
  final List<ExpenseSplitMember> members;
  final bool isEqual;
  final void Function(String memberId, bool isSelected) onSelected;

  @override
  Widget build(BuildContext context) {
    final people = isEqual
        ? members.map((member) => member.memberId).toSet()
        : item.memberIds;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '×${item.quantity}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(width: 12),
              Text(
                ExpenseSplitStrings.amount(item.amountLocal, currencyCode),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!isEqual)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var person = 0; person < members.length; person++)
                  FilterChip(
                    key: ValueKey('item-$index-person-$person'),
                    label: Text(members[person].name),
                    selected: people.contains(members[person].memberId),
                    showCheckmark: true,
                    checkmarkColor: Colors.white,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: people.contains(members[person].memberId)
                          ? Colors.white
                          : AppColors.ink,
                    ),
                    side: BorderSide(
                      color: people.contains(members[person].memberId)
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    onSelected: (value) =>
                        onSelected(members[person].memberId, value),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              people.isEmpty
                  ? ExpenseSplitStrings.selectMember
                  : ExpenseSplitStrings.perPerson(
                      people.length,
                      item.amountLocal / people.length,
                      currencyCode,
                    ),
              style: TextStyle(
                fontSize: 12,
                color: people.isEmpty ? AppColors.error : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Divider(height: 1, color: AppColors.background),
        ],
      ),
    );
  }
}
