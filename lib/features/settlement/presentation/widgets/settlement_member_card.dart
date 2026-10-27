import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settlement_models.dart';
import '../settlement_strings.dart';

class SettlementMemberCard extends StatelessWidget {
  const SettlementMemberCard({
    super.key,
    required this.member,
    required this.isMe,
    required this.onTap,
  });
  final SettlementMember member;
  final bool isMe;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final balance = member.balanceKrw;
    final color = balance > 0
        ? AppColors.success
        : balance < 0
        ? AppColors.error
        : AppColors.muted;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          member.person.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        if (isMe)
                          const Text(
                            SettlementStrings.me,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                SettlementStrings.status(balance),
                style: TextStyle(color: color, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                SettlementStrings.krw(balance.abs()),
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
