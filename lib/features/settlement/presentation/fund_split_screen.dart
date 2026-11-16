import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../data/settlement_models.dart';
import 'fund_contribution_sheet.dart';

/// 공금 목표액을 나누고 실제 납부를 기존 공금 기록에 저장한다.
class FundSplitScreen extends StatefulWidget {
  const FundSplitScreen({
    super.key,
    required this.trip,
    required this.fund,
    required this.initialTotalKrw,
    required this.onContributionChanged,
  });

  final TripDetail trip;
  final Fund fund;
  final int initialTotalKrw;
  final VoidCallback onContributionChanged;

  @override
  State<FundSplitScreen> createState() => _FundSplitScreenState();
}

class _FundSplitScreenState extends State<FundSplitScreen> {
  late Fund _fund = widget.fund;
  int _revision = 0;
  late final int _initialTotalKrw = widget.initialTotalKrw <= 999999999999
      ? widget.initialTotalKrw
      : 0;
  late int _totalKrw = _initialTotalKrw;
  late final Set<String> _selected = {
    for (final member in widget.trip.members) member.memberId,
  };

  Future<void> _refresh() async {
    final revision = ++_revision;
    try {
      final fund = await services.expenses.fund(widget.trip.id);
      if (mounted && revision == _revision) {
        setState(() => _fund = fund);
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        showError(context, error);
      }
    }
  }

  Future<void> _record(TripMember member, int dueKrw) async {
    final fund = await showFundContributionSheet(
      context,
      trip: widget.trip,
      member: member,
      suggestedKrw: dueKrw,
    );
    if (!mounted || fund == null) {
      return;
    }
    _revision++;
    setState(() => _fund = fund);
    widget.onContributionChanged();
  }

  @override
  Widget build(BuildContext context) {
    final participants = widget.trip.members
        .where((member) => _selected.contains(member.memberId))
        .toList();
    final count = participants.length;
    final isAmountValid =
        count > 0 && _totalKrw >= count && _totalKrw <= 999999999999;
    final base = isAmountValid ? _totalKrw ~/ count : 0;
    final extra = isAmountValid ? _totalKrw % count : 0;
    final paidByMember = {
      for (final member in _fund.members)
        member.member.memberId: member.contributedKrw,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('공금 N분의 1')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('모을 공금 목표액', required: true),
                  const Text(
                    '목표액과 선택한 인원은 이 화면에서 분담액을 계산할 때 사용해요.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _initialTotalKrw > 0
                        ? _initialTotalKrw.toString()
                        : '',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: const InputDecoration(
                      prefixText: '₩ ',
                      hintText: '예: 100000',
                    ),
                    onChanged: (value) {
                      setState(() => _totalKrw = int.tryParse(value) ?? 0);
                    },
                  ),
                  const SizedBox(height: 16),
                  FieldLabel('나눌 사람 · $count명'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in widget.trip.members)
                        FilterChip(
                          label: Text(member.name),
                          selected: _selected.contains(member.memberId),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selected.add(member.memberId);
                              } else {
                                _selected.remove(member.memberId);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SectionTitle('멤버별 납부'),
            if (!isAmountValid)
              AppCard(
                child: Text(
                  count == 0
                      ? '나눌 사람을 한 명 이상 선택해 주세요.'
                      : '한 사람당 최소 1원이 되도록 목표액을 입력해 주세요.',
                ),
              )
            else ...[
              for (final (index, member) in participants.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FundSplitRow(
                    member: member,
                    targetKrw: base + (index < extra ? 1 : 0),
                    paidKrw: paidByMember[member.memberId] ?? 0,
                    onRecord: (dueKrw) => _record(member, dueKrw),
                  ),
                ),
              Text(
                extra > 0
                    ? '나머지 $extra원은 목록 위에서부터 1원씩 나눴어요.'
                    : '실제로 받은 금액을 저장하면 공금 잔액에 반영돼요.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FundSplitRow extends StatelessWidget {
  const _FundSplitRow({
    required this.member,
    required this.targetKrw,
    required this.paidKrw,
    required this.onRecord,
  });

  final TripMember member;
  final int targetKrw;
  final int paidKrw;
  final ValueChanged<int> onRecord;

  @override
  Widget build(BuildContext context) {
    final due = targetKrw - paidKrw;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(member.name),
              const SizedBox(width: 8),
              Expanded(child: Text(member.name)),
              const SizedBox(width: 8),
              Text(Fmt.krw(targetKrw), style: AppTypography.money),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('납부 ${Fmt.krw(paidKrw)}'),
              Text(
                due > 0 ? '남은 납부 ${Fmt.krw(due)}' : '목표액 납부 완료',
                style: TextStyle(
                  color: due > 0 ? AppColors.muted : AppColors.success,
                ),
              ),
              if (due > 0)
                TextButton(
                  onPressed: () => onRecord(due),
                  child: const Text('납부 등록'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
