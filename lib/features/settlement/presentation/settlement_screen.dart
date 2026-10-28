import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/settlement_models.dart';
import '../data/settlement_repository.dart';
import 'settlement_controller.dart';
import 'settlement_strings.dart';
import 'widgets/settlement_member_card.dart';
import 'widgets/settlement_member_sheet.dart';
import 'widgets/settlement_summary_card.dart';
import 'widgets/settlement_transfer_card.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({
    super.key,
    required this.tripName,
    required this.currentMemberId,
    required this.repository,
    this.isPreview = false,
    this.onViewExpenses,
  });
  final String tripName, currentMemberId;
  final SettlementRepository repository;
  final bool isPreview;
  final Future<void> Function()? onViewExpenses;
  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  late final SettlementController _controller;
  @override
  void initState() {
    super.initState();
    _controller = SettlementController(
      repository: widget.repository,
      currentMemberId: widget.currentMemberId,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _expenses() async {
    await widget.onViewExpenses?.call();
    if (mounted) {
      await _controller.load();
    }
  }

  void _details(SettlementMember member, SettlementSnapshot snapshot) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.background,
        builder: (_) => SettlementMemberSheet(
          member: member,
          transfers: snapshot.transfersFor(member.person.memberId),
          currentMemberId: widget.currentMemberId,
        ),
      );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, child) {
      final result = _controller.result;
      final transfers = _controller.transfers;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 76,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                SettlementStrings.title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                widget.tripName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const ValueKey('settlement-refresh'),
              tooltip: SettlementStrings.refresh,
              onPressed: _controller.isLoading ? null : _controller.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_controller.isLoading && result != null)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: result == null
                  ? (_controller.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: SettlementNotice(
                              icon: Icons.cloud_off_outlined,
                              title:
                                  _controller.error ??
                                  SettlementStrings.loadError,
                              action: TextButton(
                                onPressed: _controller.load,
                                child: const Text(SettlementStrings.retry),
                              ),
                            ),
                          ))
                  : RefreshIndicator(
                      onRefresh: _controller.load,
                      child: ListView(
                        key: const ValueKey('settlement-list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          if (widget.isPreview) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    SettlementStrings.preview,
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    SettlementStrings.previewHint,
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_controller.error != null) ...[
                            Container(
                              key: const ValueKey('settlement-stale'),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.warningSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    SettlementStrings.stale,
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _controller.error!,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _controller.load,
                                    child: const Text(SettlementStrings.retry),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          SettlementSummaryCard(
                            totalKrw: result.totalKrw,
                            me: _controller.me,
                          ),
                          if (_controller.checkedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                SettlementStrings.checkedAt(
                                  _controller.checkedAt!,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          const SizedBox(height: 28),
                          if (result.totalKrw == 0)
                            const SettlementNotice(
                              icon: Icons.receipt_long_outlined,
                              title: SettlementStrings.empty,
                              hint: SettlementStrings.emptyHint,
                            )
                          else ...[
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    SettlementStrings.transfers,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  SettlementStrings.transferCount(
                                    transfers.length,
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  key: const ValueKey('settlement-filter-mine'),
                                  label: const Text(SettlementStrings.mine),
                                  selected: _controller.isMine,
                                  onSelected: _controller.me == null
                                      ? null
                                      : (_) => _controller.selectMine(true),
                                ),
                                ChoiceChip(
                                  key: const ValueKey('settlement-filter-all'),
                                  label: const Text(SettlementStrings.all),
                                  selected: !_controller.isMine,
                                  onSelected: (_) =>
                                      _controller.selectMine(false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (transfers.isEmpty)
                              SettlementNotice(
                                icon: Icons.check_circle_outline,
                                title: result.transfers.isEmpty
                                    ? SettlementStrings.noTransfers
                                    : SettlementStrings.noMyTransfers,
                                hint: result.transfers.isEmpty
                                    ? SettlementStrings.noTransfersHint
                                    : SettlementStrings.noMyTransfersHint,
                              ),
                            for (var i = 0; i < transfers.length; i++)
                              SettlementTransferCard(
                                key: ValueKey('settlement-transfer-$i'),
                                transfer: transfers[i],
                                currentMemberId: widget.currentMemberId,
                              ),
                            if (result.transfers.isNotEmpty)
                              Text(
                                widget.isPreview
                                    ? SettlementStrings.previewPaymentHint
                                    : SettlementStrings.paymentHint,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                          ],
                          const SizedBox(height: 28),
                          const Text(
                            SettlementStrings.members,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            SettlementStrings.memberHint,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final member in result.members)
                            SettlementMemberCard(
                              key: ValueKey(
                                'settlement-member-${member.person.memberId}',
                              ),
                              member: member,
                              isMe:
                                  member.person.memberId ==
                                  widget.currentMemberId,
                              onTap: () => _details(member, result),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: widget.onViewExpenses == null
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: FilledButton.icon(
                    key: const ValueKey('settlement-expenses'),
                    onPressed: _controller.isLoading ? null : _expenses,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text(SettlementStrings.viewExpenses),
                  ),
                ),
              ),
      );
    },
  );
}

class SettlementNotice extends StatelessWidget {
  const SettlementNotice({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 40, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            height: 1.5,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 10),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}
