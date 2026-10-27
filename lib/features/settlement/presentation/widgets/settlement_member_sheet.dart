import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settlement_models.dart';
import '../settlement_strings.dart';
import 'settlement_summary_card.dart';
import 'settlement_transfer_card.dart';

class SettlementMemberSheet extends StatelessWidget {
  const SettlementMemberSheet({
    super.key,
    required this.member,
    required this.transfers,
    required this.currentMemberId,
  });
  final SettlementMember member;
  final List<SettlementTransfer> transfers;
  final String currentMemberId;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            SettlementStrings.memberTitle(member.person.name),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          SettlementAmountRow(
            label: SettlementStrings.paid,
            amount: member.paidKrw,
          ),
          const SizedBox(height: 14),
          SettlementAmountRow(
            label: SettlementStrings.share,
            amount: member.shareKrw,
          ),
          const SizedBox(height: 14),
          SettlementAmountRow(
            label: SettlementStrings.status(member.balanceKrw),
            amount: member.balanceKrw.abs(),
          ),
          const SizedBox(height: 12),
          const Text(
            SettlementStrings.balanceHint,
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Text(
            SettlementStrings.transfers,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 12),
          if (transfers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                SettlementStrings.noTransfers,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          for (final transfer in transfers)
            SettlementTransferCard(
              transfer: transfer,
              currentMemberId: currentMemberId,
              perspectiveMemberId: member.person.memberId,
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            child: const Text(SettlementStrings.close),
          ),
        ],
      ),
    ),
  );
}
