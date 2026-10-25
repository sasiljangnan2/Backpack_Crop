import '../data/expense_request.dart';
import '../data/expense_split_repository.dart';
import 'expense_split_preview.dart';

class ExpenseSplitSelection {
  const ExpenseSplitSelection({
    required this.data,
    required this.request,
    required this.preview,
  });

  final ExpenseSplitData data;
  final ExpenseRequest request;
  final ExpenseSplitPreview preview;
}
