import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../expense/data/expense_models.dart';
import '../../trip/data/trip_models.dart';
import '../data/settlement_models.dart';

/// BP-BG-001 · 002 예산 현황 · 예상 경비 입력 (경비 탭의 "예산")
class BudgetView extends StatefulWidget {
  const BudgetView({super.key, required this.trip});

  final TripDetail trip;

  @override
  State<BudgetView> createState() => _BudgetViewState();
}

class _BudgetViewState extends State<BudgetView> {
  final _key = GlobalKey<AsyncBuilderState<Budget>>();

  Future<void> _edit({BudgetItem? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _BudgetItemSheet(trip: widget.trip, item: item),
    );
    if (saved == true) {
      await _key.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return AsyncBuilder<Budget>(
      key: _key,
      load: () => services.expenses.budget(trip.id),
      builder: (context, budget, _) {
        final ratio = budget.usedRatio;
        final hasBudget = budget.items.isNotEmpty;
        final hasLocalItems = budget.items.any((i) => i.currencyCode != 'KRW');
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '전체 예산',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Fmt.krw(budget.totalBudgetKrw),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasBudget)
                    Text(
                      '1인 준비 금액 ${Fmt.krw(budget.perPersonBudgetKrw)} · ${budget.memberCount}명 기준',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Text(
                      '아직 정한 예산이 없어요 · 지금까지 지출 ${Fmt.krw(budget.totalSpentKrw)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  if (ratio != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0, 1).toDouble(),
                        minHeight: 6,
                        backgroundColor: AppColors.background,
                        color: ratio > 1 ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '지출 ${Fmt.krw(budget.totalSpentKrw)} · ${(ratio * 100).round()}% 사용',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  if (hasLocalItems && budget.todayRate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${budget.currencyCode} 예산은 오늘 환율(${budget.todayRate!.unit}${budget.currencyCode} = '
                      '${Fmt.number(budget.todayRate!.unitRateToKrw)}원)로 환산했어요',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  if (budget.hasUnconvertedItems)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '환율을 몰라 원화로 바꾸지 못한 항목은 합계에서 빠졌어요',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (budget.summary.isNotEmpty) ...[
              const SectionTitle('분류별 예산 · 지출'),
              AppCard(
                child: Column(
                  children: [
                    for (final category in budget.summary)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  category.category.icon,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    category.category.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  category.budgetKrw == 0
                                      ? '${Fmt.krw(category.spentKrw)} · 예산 없음'
                                      : '${Fmt.krw(category.spentKrw)} / ${Fmt.krw(category.budgetKrw)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        category.budgetKrw > 0 &&
                                            category.spentKrw >
                                                category.budgetKrw
                                        ? AppColors.error
                                        : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                            // 예산을 정하지 않은 분류는 막대를 그리지 않는다 (초과처럼 보이지 않게)
                            if (category.budgetKrw > 0) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value:
                                      (category.spentKrw / category.budgetKrw)
                                          .clamp(0, 1)
                                          .toDouble(),
                                  minHeight: 4,
                                  backgroundColor: AppColors.background,
                                  color: category.spentKrw > category.budgetKrw
                                      ? AppColors.error
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            SectionTitle(
              '예산 항목',
              trailing: TextButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
              ),
            ),
            if (budget.items.isEmpty)
              AppCard(
                child: EmptyView(
                  icon: Icons.savings_outlined,
                  title: '예산을 정해 보세요',
                  message: '숙소·교통·식비 예상 금액을 넣으면\n1인 준비 금액을 계산해 드려요.',
                  action: OutlinedButton(
                    onPressed: _edit,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(160, 44),
                    ),
                    child: const Text('예산 추가'),
                  ),
                ),
              )
            else
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final item in budget.items)
                      ListTile(
                        onTap: () => _edit(item: item),
                        leading: Icon(
                          item.category.icon,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          item.category.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Fmt.money(item.amount, item.currencyCode),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (item.currencyCode != 'KRW' &&
                                item.amountKrw != null)
                              Text(
                                '≈ ${Fmt.krw(item.amountKrw!)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BudgetItemSheet extends StatefulWidget {
  const _BudgetItemSheet({required this.trip, this.item});

  final TripDetail trip;
  final BudgetItem? item;

  @override
  State<_BudgetItemSheet> createState() => _BudgetItemSheetState();
}

class _BudgetItemSheetState extends State<_BudgetItemSheet> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _amount = TextEditingController(
    text: widget.item == null
        ? ''
        : Fmt.number(widget.item!.amount).replaceAll(',', ''),
  );
  late ExpenseCategory _category =
      widget.item?.category ?? ExpenseCategory.lodging;
  late String _currency = widget.item?.currencyCode ?? 'KRW';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text);
    if (_name.text.trim().isEmpty || amount == null) {
      showSnack(context, '이름과 금액을 입력해 주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      final item = widget.item;
      if (item == null) {
        await services.expenses.createBudgetItem(
          widget.trip.id,
          category: _category,
          name: _name.text.trim(),
          amount: amount,
          currencyCode: _currency,
        );
      } else {
        await services.expenses.updateBudgetItem(
          widget.trip.id,
          item.id,
          category: _category,
          name: _name.text.trim(),
          amount: amount,
          currencyCode: _currency,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    try {
      await services.expenses.deleteBudgetItem(widget.trip.id, widget.item!.id);
      if (mounted) {
        Navigator.pop(context, true);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item == null ? '예산 추가' : '예산 수정',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in ExpenseCategory.values)
                    ChoiceChip(
                      selected: category == _category,
                      showCheckmark: false,
                      avatar: Icon(category.icon, size: 16),
                      label: Text(category.label),
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: '예: 호텔 3박',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        hintText: '금액',
                        prefixText:
                            '${Fmt.currencySymbols[_currency] ?? _currency} ',
                      ),
                    ),
                  ),
                  if (!trip.isKrwTrip) ...[
                    const SizedBox(width: 8),
                    SegmentedButton<String>(
                      segments: [
                        const ButtonSegment(value: 'KRW', label: Text('원')),
                        ButtonSegment(
                          value: trip.currencyCode,
                          label: Text(trip.currencyCode),
                        ),
                      ],
                      selected: {_currency},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) =>
                          setState(() => _currency = value.first),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('저장'),
              ),
              if (widget.item != null)
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('삭제'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
