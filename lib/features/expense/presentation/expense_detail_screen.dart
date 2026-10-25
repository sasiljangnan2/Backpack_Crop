import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/expense_repository.dart';
import 'expense_split_strings.dart';
import 'expense_strings.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    required this.onEdit,
  });
  final ExpenseRecord expense;
  final Future<ExpenseRecord?> Function(ExpenseRecord expense) onEdit;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late ExpenseRecord _expense = widget.expense;
  bool _isEditing = false;

  Future<void> _edit() async {
    if (_isEditing) {
      return;
    }
    setState(() => _isEditing = true);
    final edited = await widget.onEdit(_expense);
    if (!mounted) {
      return;
    }
    setState(() {
      _isEditing = false;
      if (edited != null) {
        _expense = edited;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _expense.data;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(ExpenseStrings.detail)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            ExpenseStrings.sample,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            data.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            ExpenseStrings.krw(_expense.amountKrw),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            ExpenseSplitStrings.amount(
              data.items.fold<num>(0, (sum, item) => sum + item.amountLocal),
              data.currencyCode,
            ),
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text(ExpenseStrings.categoryLabel(data.category))),
              Chip(label: Text(ExpenseStrings.dateLabel(data.paidDate))),
              Chip(label: Text(ExpenseStrings.payerLabel(_expense.payerName))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ExpenseSplitStrings.sampleRate(data.previewRate, data.currencyCode),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text(
            ExpenseStrings.items,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final item in _expense.request.items)
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ExpenseSplitStrings.amount(
                        item.amountLocal ?? item.amountKrw ?? 0,
                        data.currencyCode,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ExpenseStrings.itemPeople(
                        item.members.map(
                          (selected) => data.members
                              .firstWhere(
                                (member) =>
                                    member.memberId == selected.memberId,
                              )
                              .name,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            ExpenseStrings.savedSummary,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.white,
            child: Column(
              children: [
                for (final member in data.members)
                  ListTile(
                    title: Text(member.name),
                    subtitle: member.memberId == data.payerMemberId
                        ? const Text(ExpenseStrings.payer)
                        : null,
                    trailing: Text(
                      ExpenseStrings.krw(
                        _expense.sharesKrw[member.memberId] ?? 0,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton.icon(
            key: const ValueKey('expense-edit'),
            onPressed: _isEditing ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text(ExpenseStrings.edit),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        ),
      ),
    );
  }
}
