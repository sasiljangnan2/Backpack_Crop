import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/expense_repository.dart';
import '../../data/expense_request.dart';
import '../expense_split_strings.dart';
import '../expense_strings.dart';

class ExpenseRecordTile extends StatelessWidget {
  const ExpenseRecordTile({
    super.key,
    required this.expense,
    required this.currentMemberId,
    required this.onTap,
  });
  final ExpenseRecord expense;
  final String currentMemberId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (expense.request.category) {
      ExpenseCategory.food => Icons.restaurant_outlined,
      ExpenseCategory.lodging => Icons.bed_outlined,
      ExpenseCategory.transport => Icons.train_outlined,
      ExpenseCategory.activity => Icons.local_activity_outlined,
      ExpenseCategory.shopping => Icons.shopping_bag_outlined,
      ExpenseCategory.etc => Icons.receipt_long_outlined,
    };
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(icon, color: AppColors.primary, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.request.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          ExpenseStrings.payerLabel(expense.payerName),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ExpenseStrings.krw(expense.amountKrw),
                      style: AppTypography.money.copyWith(fontSize: 21),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ExpenseSplitStrings.amount(
                        expense.request.amountLocal ?? expense.amountKrw,
                        expense.data.currencyCode,
                      ),
                      style: AppTypography.money.copyWith(
                        color: AppColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  const Text(
                    ExpenseStrings.myShare,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ExpenseStrings.krw(
                        expense.sharesKrw[currentMemberId] ?? 0,
                      ),
                      style: AppTypography.money.copyWith(
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
