import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../data/settlement_models.dart';
import 'fund_contribution_sheet.dart';
import 'fund_split_screen.dart';

/// 예산 화면의 공금: 남은 금액, 예산과 비교, 사람별로 모은 돈, 모은 내역
class FundSection extends StatelessWidget {
  const FundSection({
    super.key,
    required this.trip,
    required this.budget,
    required this.onChanged,
  });

  final TripDetail trip;
  final Budget budget;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context, {FundContribution? item}) async {
    final saved = await showFundContributionSheet(
      context,
      trip: trip,
      item: item,
    );
    if (saved != null && context.mounted) {
      onChanged();
    }
  }

  Future<void> _split(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FundSplitScreen(
          trip: trip,
          fund: budget.fund,
          initialTotalKrw: budget.hasUnconvertedItems
              ? 0
              : budget.totalBudgetKrw,
          onContributionChanged: () {
            if (context.mounted) {
              onChanged();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fund = budget.fund;
    final collected = fund.collectedKrw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          '공금',
          trailing: TextButton.icon(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('공금 모으기'),
          ),
        ),
        OutlinedButton.icon(
          onPressed: trip.members.isEmpty ? null : () => _split(context),
          icon: const Icon(Icons.groups_outlined),
          label: const Text('공금 N분의 1'),
        ),
        const SizedBox(height: 12),
        if (collected == 0 && fund.spentKrw == 0)
          AppCard(
            child: EmptyView(
              icon: Icons.account_balance_wallet_outlined,
              title: '공금을 모아 볼까요?',
              message: budget.perPersonBudgetKrw > 0
                  ? '예산대로라면 1인당 ${Fmt.krw(budget.perPersonBudgetKrw)}이에요.\n모아 둔 돈에서 내면 지출할 때마다 나누지 않아도 돼요.'
                  : '모아 둔 돈에서 내면 지출할 때마다 나누지 않아도 돼요.\n남은 돈은 정산에서 돌려받아요.',
              action: OutlinedButton(
                onPressed: () => _edit(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                ),
                child: const Text('공금 모으기'),
              ),
            ),
          )
        else ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '남은 공금',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  Fmt.krw(fund.remainingKrw),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: fund.remainingKrw < 0 ? AppColors.error : null,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: collected == 0
                        ? 1
                        : (fund.spentKrw / collected).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: AppColors.background,
                    color: fund.remainingKrw < 0
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '모은 돈 ${Fmt.krw(collected)} · 쓴 돈 ${Fmt.krw(fund.spentKrw)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (budget.totalBudgetKrw > 0) ...[
                  const SizedBox(height: 10),
                  _BudgetCompare(budget: budget),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final total in fund.members)
                  _MemberRow(
                    total: total,
                    perPerson: budget.perPersonBudgetKrw,
                    isMe: total.member.memberId == trip.myMemberId,
                  ),
              ],
            ),
          ),
          if (fund.contributions.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final item in fund.contributions)
                    ListTile(
                      onTap: item.canEdit
                          ? () => _edit(context, item: item)
                          : null,
                      leading: MemberAvatar(item.member.name),
                      title: Text(
                        '${item.member.name}님이 모음',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${Fmt.monthDay(item.contributedOn)}'
                        '${item.memo == null ? '' : ' · ${item.memo}'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        Fmt.krw(item.amountKrw),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// 모은 돈과 전체 예산 비교: 얼마나 더 모아야 하는지
class _BudgetCompare extends StatelessWidget {
  const _BudgetCompare({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final gap = budget.totalBudgetKrw - budget.fund.collectedKrw;
    final enough = gap <= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: enough ? AppColors.successSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            enough ? Icons.check_circle_outline : Icons.savings_outlined,
            size: 16,
            color: enough ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              enough
                  ? '예산 ${Fmt.krw(budget.totalBudgetKrw)}을 다 모았어요'
                  : '예산 ${Fmt.krw(budget.totalBudgetKrw)}까지 ${Fmt.krw(gap)} 더 모아야 해요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: enough ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 사람별로 모은 돈과 1인 준비 금액 비교
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.total,
    required this.perPerson,
    required this.isMe,
  });

  final FundMemberTotal total;
  final int perPerson;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final short = perPerson - total.contributedKrw;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MemberAvatar(total.member.name, radius: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '${total.member.name} (나)' : total.member.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.krw(total.contributedKrw),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (perPerson > 0)
                Text(
                  short > 0 ? '${Fmt.krw(short)} 더' : '1인 금액 채움',
                  style: TextStyle(
                    fontSize: 11,
                    color: short > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
