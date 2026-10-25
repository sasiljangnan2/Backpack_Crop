import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../data/expense_models.dart';
import 'expense_form_screen.dart';

/// BP-EX-005 지출 상세. 고치거나 지우면 true를 돌려준다.
class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.trip,
    required this.expenseId,
  });

  final TripDetail trip;
  final String expenseId;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final _key = GlobalKey<AsyncBuilderState<ExpenseDetail>>();
  bool _changed = false;

  // 결제자 · 작성자 · 방장만 고칠 수 있다 (서버도 같은 규칙으로 막는다)
  bool _canEdit(ExpenseDetail expense) =>
      widget.trip.isHost ||
      expense.payer.memberId == widget.trip.myMemberId ||
      expense.creator.memberId == widget.trip.myMemberId;

  Future<void> _edit(ExpenseDetail expense) async {
    final saved = await Navigator.of(context).push<ExpenseDetail>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(trip: widget.trip, existing: expense),
      ),
    );
    if (saved != null) {
      _changed = true;
      await _key.currentState?.reload();
    }
  }

  Future<void> _delete(ExpenseDetail expense) async {
    final ok = await confirm(
      context,
      title: '지출을 삭제할까요?',
      message: "'${expense.title}' ${Fmt.krw(expense.amountKrw)}이 정산에서 빠져요.",
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await services.expenses.delete(widget.trip.id, expense.id!);
      if (mounted) {
        Navigator.pop(context, true);
        showSnack(context, '지출을 삭제했어요.');
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pop(context, _changed);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('지출 상세')),
        body: AsyncBuilder<ExpenseDetail>(
          key: _key,
          load: () => services.expenses.expense(trip.id, widget.expenseId),
          builder: (context, expense, _) {
            final rateText = switch (expense.rateMode) {
              RateMode.api => '그날 환율',
              RateMode.prepaid => '결제자 환전 환율',
              RateMode.manual => '직접 입력 환율',
              RateMode.krw => '원화 결제',
            };
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            expense.category.icon,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${expense.category.label} · ${Fmt.longDate(expense.paidDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Fmt.krw(expense.amountKrw),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (expense.amountLocal != null)
                        Text(
                          '${Fmt.money(expense.amountLocal!, trip.currencyCode)} × ${Fmt.number(expense.appliedRate ?? 0)}'
                          ' · $rateText${expense.rateDate == null ? '' : ' (${Fmt.monthDay(expense.rateDate!)})'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        )
                      else
                        Text(
                          rateText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        '${expense.payer.name}님 결제'
                        '${expense.creator.memberId == expense.payer.memberId ? '' : ' · ${expense.creator.name}님이 입력'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in expense.items) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              Fmt.krw(item.amountKrw),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final share in item.members)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                MemberAvatar(share.name, radius: 12),
                                const SizedBox(width: 8),
                                Expanded(child: Text(share.name)),
                                Text(Fmt.krw(share.shareKrw)),
                              ],
                            ),
                          ),
                        if (item.remainderKrw > 0 &&
                            item.remainderMember != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '끝전 ${Fmt.krw(item.remainderKrw)}은 ${item.remainderMember!.name}님 부담',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_canEdit(expense)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _delete(expense),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('삭제'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _edit(expense),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('수정'),
                        ),
                      ),
                    ],
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '결제자 · 입력한 사람 · 방장만 수정할 수 있어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
