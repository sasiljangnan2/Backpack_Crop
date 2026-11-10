import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../settlement/presentation/budget_view.dart';
import '../../settlement/presentation/settlement_screen.dart';
import '../../settlement/data/settlement_models.dart';
import '../../trip/data/trip_models.dart';
import '../../trip/presentation/trip_shell.dart';
import '../data/expense_models.dart';
import 'expense_detail_screen.dart';
import 'receipt_capture_screen.dart';
import 'widgets/expense_summary_card.dart';

/// 경비 탭: 지출(BP-EX-001) · 정산(BP-ST-001) · 예산(BP-BG)
class ExpenseTab extends StatefulWidget {
  const ExpenseTab({super.key});

  @override
  State<ExpenseTab> createState() => _ExpenseTabState();
}

class _ExpenseTabState extends State<ExpenseTab> with TripTabRefresh {
  int _view = 0;
  final _expenses = GlobalKey<_ExpenseListViewState>();
  int _settlementRevision = 0;

  @override
  int get tabIndex => TripShell.expense;

  @override
  void onTabShown() {
    _expenses.currentState?.reload();
    setState(() => _settlementRevision++);
  }

  Future<void> _add() async {
    final scope = TripScope.of(context);
    final created = await Navigator.of(context).push<ExpenseDetail>(
      // 지출 등록 1/3 영수증 촬영 (직접 입력도 여기서 고른다)
      MaterialPageRoute(builder: (_) => ReceiptCaptureScreen(trip: scope.trip)),
    );
    if (created != null) {
      _expenses.currentState?.reload();
      setState(() => _settlementRevision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = TripScope.of(context).trip;
    return Scaffold(
      appBar: AppBar(
        title: const Text('경비', key: ValueKey('expense-screen-title')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                trip.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('지출')),
                  ButtonSegment(value: 1, label: Text('정산')),
                  ButtonSegment(value: 2, label: Text('예산')),
                ],
                selected: {_view},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() {
                  _view = value.first;
                  if (_view == 1) {
                    _settlementRevision++;
                  }
                }),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _view == 0
          ? FloatingActionButton.extended(
              heroTag: 'expense-add',
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('지출 추가'),
            )
          : null,
      body: IndexedStack(
        index: _view,
        children: [
          _ExpenseListView(
            key: _expenses,
            trip: trip,
            onChanged: () => setState(() => _settlementRevision++),
            onSettlement: () => setState(() {
              _view = 1;
              _settlementRevision++;
            }),
          ),
          SettlementView(
            key: ValueKey('settlement-$_settlementRevision'),
            trip: trip,
          ),
          BudgetView(key: ValueKey('budget-$_settlementRevision'), trip: trip),
        ],
      ),
    );
  }
}

class _ExpenseListView extends StatefulWidget {
  const _ExpenseListView({
    super.key,
    required this.trip,
    required this.onChanged,
    required this.onSettlement,
  });

  final TripDetail trip;
  final VoidCallback onChanged;
  final VoidCallback onSettlement;

  @override
  State<_ExpenseListView> createState() => _ExpenseListViewState();
}

class _ExpenseListViewState extends State<_ExpenseListView> {
  final List<ExpenseListItem> _items = [];
  ExpensePage? _first;
  String? _cursor;
  bool _hasNext = false;
  bool _loadingMore = false;
  Object? _error;
  ExpenseCategory? _category;
  MySettlement? _mine;
  Budget? _budget;
  bool _overviewFailed = false;
  int _generation = 0;
  int _overviewGeneration = 0;

  Future<void> _loadOverview() async {
    final generation = ++_overviewGeneration;
    var failed = false;
    await Future.wait([
      () async {
        try {
          final mine = await services.expenses.mySettlement(widget.trip.id);
          if (mounted && generation == _overviewGeneration) {
            setState(() => _mine = mine);
          }
        } catch (_) {
          failed = true;
        }
      }(),
      () async {
        try {
          final budget = await services.expenses.budget(widget.trip.id);
          if (mounted && generation == _overviewGeneration) {
            setState(() => _budget = budget);
          }
        } catch (_) {
          failed = true;
        }
      }(),
    ]);
    if (mounted && generation == _overviewGeneration) {
      setState(() => _overviewFailed = failed);
    }
  }

  void _filter(ExpenseCategory? category) {
    setState(() {
      _category = category;
      _first = null;
      _error = null;
      _loadingMore = false;
    });
    reload(refreshOverview: false);
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload({bool refreshOverview = true}) async {
    final generation = ++_generation;
    _loadingMore = false;
    if (refreshOverview) {
      _loadOverview();
    }
    try {
      final page = await services.expenses.expenses(
        widget.trip.id,
        category: _category,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _first = page;
        _items
          ..clear()
          ..addAll(page.content);
        _cursor = page.nextCursor;
        _hasNext = page.hasNext;
        _error = null;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e);
        if (_first != null) {
          showError(context, e);
        }
      }
    }
  }

  Future<void> _more() async {
    if (_loadingMore || !_hasNext) {
      return;
    }
    setState(() => _loadingMore = true);
    final generation = _generation;
    try {
      final page = await services.expenses.expenses(
        widget.trip.id,
        cursor: _cursor,
        category: _category,
      );
      if (mounted && generation == _generation) {
        setState(() {
          _items.addAll(page.content);
          _cursor = page.nextCursor;
          _hasNext = page.hasNext;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        showError(context, e);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _open(ExpenseListItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ExpenseDetailScreen(trip: widget.trip, expenseId: item.id),
      ),
    );
    if (changed == true) {
      await reload();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _first;
    if (first == null) {
      return _error == null
          ? const LoadingView()
          : ErrorView(error: _error!, onRetry: reload);
    }
    final rate = first.todayRate;
    final byDate = <DateTime, List<ExpenseListItem>>{};
    for (final item in _items) {
      byDate.putIfAbsent(item.paidDate, () => []).add(item);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 300) {
          _more();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            ExpenseSummaryCard(
              totalKrw: _category == null
                  ? first.totalKrw
                  : first.byCategory.fold<int>(
                      0,
                      (sum, entry) => sum + entry.$2,
                    ),
              budgetKrw: _budget?.hasUnconvertedItems == true
                  ? null
                  : _budget?.totalBudgetKrw,
              myShareKrw: _mine?.shareKrw,
              hasOverviewError: _overviewFailed,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onSettlement,
              // 분담 계산 결과를 같은 경비 탭의 정산 보기에서 확인한다.
              icon: const Icon(Icons.swap_horiz),
              label: const Text('정산 미리보기'),
            ),
            if (_overviewFailed)
              TextButton.icon(
                onPressed: _loadOverview,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('요약 정보 갱신 실패 · 다시 불러오기'),
              ),
            if (_budget?.hasUnconvertedItems == true)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('환율을 확인하지 못한 예산 항목이 있어요.'),
              ),
            if (rate != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${rate.unit}${widget.trip.currencyCode} = ${Fmt.number(rate.unitRateToKrw)}원 · ${Fmt.monthDay(rate.rateDate)} 기준',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: const Text('전체'),
                      selected: _category == null,
                      onSelected: (_) => _filter(null),
                    ),
                  ),
                  for (final category in ExpenseCategory.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: (_) => _filter(category),
                      ),
                    ),
                ],
              ),
            ),
            if (_category != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${_category!.label} ${first.count}건 · ${Fmt.krw(first.totalKrw)}',
                ),
              ),
            if (first.byCategory.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CategoryRatio(byCategory: first.byCategory),
            ],
            const SizedBox(height: 20),
            if (_items.isEmpty)
              const AppCard(
                child: EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: '첫 지출을 등록해 보세요',
                  message: '누가 냈는지만 기록하면 정산은 자동으로 계산돼요.',
                ),
              ),
            for (final entry in byDate.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(
                  Fmt.shortDate(entry.key),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              for (final item in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(18),
                    onTap: () => _open(item),
                    child: _ExpenseRow(item: item, trip: widget.trip),
                  ),
                ),
            ],
            if (_loadingMore) const LoadingView(),
          ],
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.item, required this.trip});
  final ExpenseListItem item;
  final TripDetail trip;

  @override
  Widget build(BuildContext context) {
    final local = item.amountLocal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primarySoft,
              child: Icon(
                item.category.icon,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.titleKo case final ko?)
                    Text(
                      ko,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    item.paidFromFund ? '공금에서 결제' : '${item.payer.name} 결제',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  if (item.isProxy)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Pill(
                        '대리 입력',
                        color: AppColors.muted,
                        background: AppColors.background,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              Fmt.krw(item.amountKrw),
              style: AppTypography.money.copyWith(fontSize: 24),
            ),
            if (local != null)
              Text(
                Fmt.money(local, trip.currencyCode),
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text(
              '내 부담액',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            Text(
              Fmt.krw(item.myShareKrw),
              style: AppTypography.money.copyWith(
                color: AppColors.primary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 분류별 비율 막대 (스토리보드 BP-EX-001 ②)
class _CategoryRatio extends StatelessWidget {
  const _CategoryRatio({required this.byCategory});

  final List<(ExpenseCategory, int)> byCategory;

  @override
  Widget build(BuildContext context) {
    final total = byCategory.fold<int>(0, (sum, e) => sum + e.$2);
    if (total <= 0) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (category, amount) in byCategory)
                  Expanded(
                    flex: (amount * 1000 / total).round().clamp(1, 1000),
                    child: ColoredBox(color: category.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final (category, amount) in byCategory)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${category.label} ${(amount * 100 / total).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
