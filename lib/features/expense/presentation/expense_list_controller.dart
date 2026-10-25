import 'package:flutter/foundation.dart';

import '../data/expense_repository.dart';
import '../data/expense_request.dart';
import 'expense_split_selection.dart';

class ExpenseListController extends ChangeNotifier {
  ExpenseListController(this._repository);
  final ExpenseRepository _repository;
  ExpenseTripContext? _trip;
  List<ExpenseRecord> _expenses = const [];
  ExpenseCategory? _category;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDisposed = false;
  int _loadVersion = 0;
  int _nextId = 0;

  ExpenseTripContext? get trip => _trip;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  ExpenseCategory? get category => _category;
  List<ExpenseRecord> get expenses => List.unmodifiable(
    _expenses.where(
      (expense) => _category == null || expense.request.category == _category,
    ),
  );
  int get totalKrw => _expenses.fold(0, (sum, item) => sum + item.amountKrw);
  int get myShareKrw => _expenses.fold(
    0,
    (sum, item) => sum + (item.sharesKrw[_trip?.currentMemberId] ?? 0),
  );

  Future<void> load() async {
    final version = ++_loadVersion;
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      final overview = await _repository.loadExpenses();
      if (_isDisposed || version != _loadVersion) {
        return;
      }
      _trip = overview.trip;
      _expenses = _sorted(overview.expenses);
    } on Object {
      if (_isDisposed || version != _loadVersion) {
        return;
      }
      _hasError = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  void filter(ExpenseCategory? category) {
    _category = category;
    notifyListeners();
  }

  Future<ExpenseRecord> save(
    ExpenseSplitSelection selection, {
    String? id,
  }) async {
    final preview = selection.preview;
    final record = ExpenseRecord(
      id: id ?? 'preview-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
      data: selection.data,
      request: selection.request,
      amountKrw: preview.totalWon,
      sharesKrw: {
        for (var i = 0; i < selection.data.members.length; i++)
          selection.data.members[i].memberId: preview.amountsWon[i],
      },
    );
    final saved = await _repository.saveExpense(record);
    if (!_isDisposed) {
      _expenses = _sorted([
        saved,
        ..._expenses.where((expense) => expense.id != saved.id),
      ]);
      // A newly saved expense should remain visible even after a category filter.
      _category = null;
      notifyListeners();
    }
    return saved;
  }

  List<ExpenseRecord> _sorted(List<ExpenseRecord> items) =>
      [...items]
        ..sort((a, b) => b.request.paidDate.compareTo(a.request.paidDate));

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
