import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settlement_models.dart';
import '../settlement_strings.dart';

class SettlementSummaryCard extends StatelessWidget {
  const SettlementSummaryCard({
    super.key,
    required this.totalKrw,
    required this.me,
  });
  final int totalKrw;
  final SettlementMember? me;
  @override
  Widget build(BuildContext context) {
    final member = me;
    final balance = member?.balanceKrw ?? 0;
    final color = balance > 0
        ? AppColors.success
        : balance < 0
        ? AppColors.error
        : AppColors.ink;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              SettlementStrings.total,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              SettlementStrings.krw(totalKrw),
              key: const ValueKey('settlement-total'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1),
            ),
            if (member == null)
              const Text(
                SettlementStrings.missingMe,
                style: TextStyle(color: AppColors.muted, height: 1.5),
              )
            else ...[
              const Text(
                SettlementStrings.mySettlement,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    balance > 0
                        ? Icons.south_west
                        : balance < 0
                        ? Icons.north_east
                        : Icons.check_circle_outline,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      SettlementStrings.status(balance),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                SettlementStrings.krw(balance.abs()),
                key: const ValueKey('settlement-my-balance'),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 20),
              SettlementAmountRow(
                label: SettlementStrings.paid,
                amount: member.paidKrw,
              ),
              const SizedBox(height: 10),
              SettlementAmountRow(
                label: SettlementStrings.share,
                amount: member.shareKrw,
              ),
              const SizedBox(height: 14),
              const Text(
                SettlementStrings.balanceHint,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettlementAmountRow extends StatelessWidget {
  const SettlementAmountRow({
    super.key,
    required this.label,
    required this.amount,
  });
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isStacked =
          constraints.maxWidth < 240 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.2;
      final title = Text(label, style: const TextStyle(color: AppColors.muted));
      final value = Text(
        SettlementStrings.krw(amount),
        style: const TextStyle(fontWeight: FontWeight.w700),
      );
      return isStacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 4), value],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                Flexible(child: value),
              ],
            );
    },
  );
}
