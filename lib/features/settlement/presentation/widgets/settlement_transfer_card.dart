import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settlement_models.dart';
import '../settlement_strings.dart';

class SettlementTransferCard extends StatelessWidget {
  const SettlementTransferCard({
    super.key,
    required this.transfer,
    required this.currentMemberId,
    this.perspectiveMemberId,
  });
  final SettlementTransfer transfer;
  final String currentMemberId;
  final String? perspectiveMemberId;
  @override
  Widget build(BuildContext context) {
    final perspective = perspectiveMemberId ?? currentMemberId;
    final isSending = transfer.from.memberId == perspective;
    final isReceiving = transfer.to.memberId == perspective;
    final color = isSending
        ? AppColors.error
        : isReceiving
        ? AppColors.success
        : AppColors.ink;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  SettlementStrings.person(
                    transfer.from.name,
                    transfer.from.memberId,
                    currentMemberId,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: AppColors.muted,
                ),
                Text(
                  SettlementStrings.person(
                    transfer.to.name,
                    transfer.to.memberId,
                    currentMemberId,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isSending || isReceiving) ...[
              Text(
                isSending ? SettlementStrings.send : SettlementStrings.receive,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
            ],
            Text(
              SettlementStrings.krw(transfer.amountKrw),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
