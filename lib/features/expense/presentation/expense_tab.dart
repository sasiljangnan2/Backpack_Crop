import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../settlement/presentation/budget_view.dart';
import '../../settlement/presentation/settlement_screen.dart';
import '../../trip/data/trip_models.dart';
import '../../trip/presentation/trip_shell.dart';
import '../data/expense_models.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';

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
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(trip: scope.trip)),
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
        title: const Text('경비'),
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
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('지출 등록'),
            )
          : null,
      body: IndexedStack(
        index: _view,
        children: [
          _ExpenseListView(
            key: _expenses,
            trip: trip,
            onChanged: () => setState(() => _settlementRevision++),
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
  });

  final TripDetail trip;
  final VoidCallback onChanged;

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

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final page = await services.expenses.expenses(widget.trip.id);
      if (!mounted) {
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
      if (mounted) {
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
    try {
      final page = await services.expenses.expenses(
        widget.trip.id,
        cursor: _cursor,
      );
      if (mounted) {
        setState(() {
          _items.addAll(page.content);
          _cursor = page.nextCursor;
          _hasNext = page.hasNext;
        });
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
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
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공동 지출 · ${first.count}건',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Fmt.krw(first.totalKrw),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (rate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${rate.unit}${widget.trip.currencyCode} = ${Fmt.number(rate.unitRateToKrw)}원 · '
                      '${Fmt.monthDay(rate.rateDate)} 기준',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
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
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final item in entry.value)
                      _ExpenseRow(
                        item: item,
                        trip: widget.trip,
                        onTap: () => _open(item),
                      ),
                  ],
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
  const _ExpenseRow({
    required this.item,
    required this.trip,
    required this.onTap,
  });

  final ExpenseListItem item;
  final TripDetail trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = item.amountLocal;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(item.category.icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        '${item.isPaidByMe ? '내가' : '${item.payer.name}님이'} 결제'
        '${local == null ? '' : ' · ${Fmt.money(local, trip.currencyCode)}'}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Fmt.krw(item.amountKrw),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            item.myShareKrw == 0 ? '내 몫 없음' : '내 몫 ${Fmt.krw(item.myShareKrw)}',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
