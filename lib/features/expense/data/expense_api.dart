import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../settlement/data/settlement_models.dart';
import 'expense_models.dart';

/// 지출 · 환율 · 정산 · 예산 API
class ExpenseApi {
  const ExpenseApi(this._api);

  final ApiClient _api;

  Future<ExpensePage> expenses(
    String tripId, {
    String? cursor,
    ExpenseCategory? category,
    int size = 30,
  }) async => ExpensePage.fromJson(
    await _api.get(
      '/api/trips/$tripId/expenses',
      query: {
        'cursor': cursor,
        'category': category == null ? null : enumName(category),
        'size': size,
      },
    ) as Json,
  );

  Future<ExpenseDetail> expense(String tripId, String expenseId) async =>
      ExpenseDetail.fromJson(
        await _api.get('/api/trips/$tripId/expenses/$expenseId') as Json,
      );

  Future<ExpenseDetail> preview(String tripId, ExpenseDraft draft) async =>
      ExpenseDetail.fromJson(
        await _api.post(
          '/api/trips/$tripId/expenses/preview',
          body: draft.toJson(),
        ) as Json,
      );

  Future<ExpenseDetail> create(String tripId, ExpenseDraft draft) async =>
      ExpenseDetail.fromJson(
        await _api.post('/api/trips/$tripId/expenses', body: draft.toJson())
            as Json,
      );

  Future<ExpenseDetail> update(
    String tripId,
    String expenseId,
    ExpenseDraft draft,
  ) async => ExpenseDetail.fromJson(
    await _api.put(
      '/api/trips/$tripId/expenses/$expenseId',
      body: draft.toJson(),
    ) as Json,
  );

  Future<void> delete(String tripId, String expenseId) =>
      _api.delete('/api/trips/$tripId/expenses/$expenseId');

  Future<ExchangeRate> rate(String currencyCode, {DateTime? date}) async =>
      ExchangeRate.fromJson(
        await _api.get(
          '/api/exchange-rates',
          query: {
            'currencyCode': currencyCode,
            'date': date == null ? null : dateParam(date),
          },
        ) as Json,
      );

  // ---- 정산

  Future<Settlement> settlement(String tripId) async => Settlement.fromJson(
    await _api.get('/api/trips/$tripId/settlement') as Json,
  );

  Future<MySettlement> mySettlement(String tripId) async =>
      MySettlement.fromJson(
        await _api.get('/api/trips/$tripId/settlement/me') as Json,
      );

  Future<SettlementShare> share(String tripId) async =>
      SettlementShare.fromJson(
        await _api.post('/api/trips/$tripId/settlement-shares') as Json,
      );

  Future<List<SettlementShareSummary>> shares(String tripId) async => list(
    await _api.get('/api/trips/$tripId/settlement-shares'),
    SettlementShareSummary.fromJson,
  );

  Future<SettlementShare> shareDetail(String tripId, String shareId) async =>
      SettlementShare.fromJson(
        await _api.get('/api/trips/$tripId/settlement-shares/$shareId') as Json,
      );

  // ---- 예산

  Future<Budget> budget(String tripId) async => Budget.fromJson(
    await _api.get('/api/trips/$tripId/budget-items') as Json,
  );

  Future<void> createBudgetItem(
    String tripId, {
    required ExpenseCategory category,
    required String name,
    required double amount,
    required String currencyCode,
  }) => _api.post(
    '/api/trips/$tripId/budget-items',
    body: {
      'category': enumName(category),
      'name': name,
      'amount': amount,
      'currencyCode': currencyCode,
    },
  );

  Future<void> updateBudgetItem(
    String tripId,
    String itemId, {
    required ExpenseCategory category,
    required String name,
    required double amount,
    required String currencyCode,
  }) => _api.patch(
    '/api/trips/$tripId/budget-items/$itemId',
    body: {
      'category': enumName(category),
      'name': name,
      'amount': amount,
      'currencyCode': currencyCode,
    },
  );

  Future<void> deleteBudgetItem(String tripId, String itemId) =>
      _api.delete('/api/trips/$tripId/budget-items/$itemId');
}
