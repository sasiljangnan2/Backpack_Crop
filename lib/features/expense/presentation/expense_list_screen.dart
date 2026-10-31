import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../settlement/data/preview_settlement_repository.dart';
import '../../settlement/presentation/settlement_screen.dart';
import '../../settlement/presentation/settlement_strings.dart';
import '../data/expense_repository.dart';
import '../data/expense_request.dart';
import '../data/memory_expense_repository.dart';
import 'expense_detail_screen.dart';
import 'expense_entry_screen.dart';
import 'expense_list_controller.dart';
import 'expense_strings.dart';
import 'widgets/expense_record_tile.dart';
import 'widgets/expense_summary_card.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({
    super.key,
    this.repository,
    this.isEmbedded = false,
  });
  final ExpenseRepository? repository;
  final bool isEmbedded;

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  late final ExpenseListController _controller;
  late final ExpenseRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MemoryExpenseRepository();
    _controller = ExpenseListController(_repository)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<ExpenseRecord?> _edit([ExpenseRecord? expense]) async {
    final trip = _controller.trip;
    if (trip == null) {
      return null;
    }
    final saved = await Navigator.push<ExpenseRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseEntryScreen(
          trip: trip,
          initial: expense,
          onSave: (selection) => _controller.save(selection, id: expense?.id),
        ),
      ),
    );
    if (!mounted || saved == null) {
      return saved;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          expense == null ? ExpenseStrings.saved : ExpenseStrings.updated,
        ),
      ),
    );
    return saved;
  }

  void _detail(ExpenseRecord expense) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ExpenseDetailScreen(expense: expense, onEdit: _edit),
    ),
  );

  void _settlement() {
    final trip = _controller.trip;
    if (trip == null) {
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SettlementScreen(
          tripName: trip.tripName,
          currentMemberId: trip.currentMemberId,
          repository: PreviewSettlementRepository(_repository),
          isPreview: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, child) {
      final trip = _controller.trip;
      final expenses = _controller.expenses;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isEmbedded,
          title: const Text(
            ExpenseStrings.title,
            key: ValueKey('expense-screen-title'),
          ),
          actions: [
            if (trip != null)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  trip.tripName,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
          ],
        ),
        floatingActionButton:
            trip == null || _controller.isLoading || _controller.hasError
            ? null
            : FloatingActionButton.extended(
                key: const ValueKey('expense-add'),
                onPressed: _edit,
                icon: const Icon(Icons.add),
                label: const Text(ExpenseStrings.add),
              ),
        body: _controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _controller.hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(ExpenseStrings.loadError),
                    TextButton(
                      onPressed: _controller.load,
                      child: const Text(ExpenseStrings.retry),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _controller.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
                  children: [
                    ExpenseSummaryCard(
                      totalKrw: _controller.totalKrw,
                      myShareKrw: _controller.myShareKrw,
                      budgetKrw: trip!.budgetKrw,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      key: const ValueKey('expense-settlement'),
                      onPressed: _settlement,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text(SettlementStrings.previewOpen),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      ExpenseStrings.sample,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final category in <ExpenseCategory?>[
                            null,
                            ...ExpenseCategory.values,
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  category == null
                                      ? ExpenseStrings.all
                                      : ExpenseStrings.categoryLabel(category),
                                ),
                                selected: _controller.category == category,
                                showCheckmark: false,
                                onSelected: (_) => _controller.filter(category),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (expenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 42,
                              color: AppColors.muted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _controller.category == null
                                  ? ExpenseStrings.empty
                                  : ExpenseStrings.filterEmpty,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_controller.category == null)
                              const Text(
                                ExpenseStrings.emptyHint,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    for (var i = 0; i < expenses.length; i++) ...[
                      if (i == 0 ||
                          expenses[i - 1].request.paidDate !=
                              expenses[i].request.paidDate)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 8),
                          child: Text(
                            ExpenseStrings.dateGroup(
                              expenses[i].request.paidDate,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ExpenseRecordTile(
                        key: ValueKey(expenses[i].id),
                        expense: expenses[i],
                        currentMemberId: trip.currentMemberId,
                        onTap: () => _detail(expenses[i]),
                      ),
                    ],
                  ],
                ),
              ),
      );
    },
  );
}
