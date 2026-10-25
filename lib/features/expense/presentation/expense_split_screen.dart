import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/expense_split_repository.dart';
import '../data/sample_expense_split_repository.dart';
import 'expense_split_controller.dart';
import 'expense_split_preview.dart';
import 'expense_split_strings.dart';
import 'widgets/expense_split_content.dart';
import 'widgets/expense_split_result_sheet.dart';

class ExpenseSplitScreen extends StatefulWidget {
  const ExpenseSplitScreen({
    super.key,
    this.repository = const SampleExpenseSplitRepository(),
    this.canConfirm = false,
  });

  final ExpenseSplitRepository repository;
  final bool canConfirm;

  @override
  State<ExpenseSplitScreen> createState() => _ExpenseSplitScreenState();
}

class _ExpenseSplitScreenState extends State<ExpenseSplitScreen> {
  late final ExpenseSplitController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExpenseSplitController(widget.repository)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _help() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (context) => const SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ExpenseSplitStrings.helpTitle,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 16),
            Text(
              ExpenseSplitStrings.helpBody,
              style: TextStyle(
                fontSize: 15,
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showResult(ExpenseSplitPreview result) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => ExpenseSplitResultSheet(
        data: _controller.data!,
        result: result,
        isEqual: _controller.isEqual,
        payerMemberId: _controller.payerMemberId,
        onConfirm: widget.canConfirm
            ? () => Navigator.pop(context, true)
            : null,
        onCopied: () {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(content: Text(ExpenseSplitStrings.copied)),
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      final selection = _controller.createSelection();
      if (selection != null) {
        Navigator.pop(context, selection);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, child) {
      if (_controller.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (_controller.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text(ExpenseSplitStrings.title)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(ExpenseSplitStrings.loadError),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _controller.load,
                  child: const Text(ExpenseSplitStrings.retry),
                ),
              ],
            ),
          ),
        );
      }
      return ExpenseSplitContent(
        controller: _controller,
        onHelp: _help,
        onResult: _showResult,
      );
    },
  );
}
