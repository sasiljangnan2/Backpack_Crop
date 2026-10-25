import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../expense_strings.dart';

class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({
    super.key,
    required this.totalKrw,
    required this.myShareKrw,
    required this.budgetKrw,
  });
  final int totalKrw;
  final int myShareKrw;
  final int budgetKrw;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          ExpenseStrings.total,
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            ExpenseStrings.krw(totalKrw),
            key: const ValueKey('expense-total'),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: budgetKrw <= 0 ? 0 : (totalKrw / budgetKrw).clamp(0, 1),
          color: Colors.white,
          backgroundColor: Colors.white24,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 10),
        Text(
          ExpenseStrings.budget(budgetKrw),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Colors.white24),
        ),
        Row(
          children: [
            const Expanded(
              child: Text(
                ExpenseStrings.myShare,
                style: TextStyle(color: Colors.white),
              ),
            ),
            Text(
              ExpenseStrings.krw(myShareKrw),
              key: const ValueKey('expense-my-share'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
