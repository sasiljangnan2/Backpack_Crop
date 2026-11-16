import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../settlement/data/settlement_models.dart';
import 'expense_models.dart';
import 'receipt_parser.dart';

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

  /// 영수증 사진을 서버(Gemini)가 읽는다 (항목 · 수량 · 금액 + 한국어 번역).
  /// 사진을 올리고 AI가 읽는 데 5~20초쯤 걸려 40초까지 기다린다
  Future<ReceiptScan> scanReceipt(String tripId, String imagePath) async =>
      ReceiptScan.fromJson(
        await _api.postFile(
          '/api/trips/$tripId/receipts/scan',
          field: 'image',
          filePath: imagePath,
          timeout: const Duration(seconds: 40),
        ) as Json,
      );

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

  // ---- 공금

  Future<Fund> fund(String tripId) async =>
      Fund.fromJson(await _api.get('/api/trips/$tripId/fund') as Json);

  Future<Fund> addFundContribution(
    String tripId, {
    required String memberId,
    required int amountKrw,
    String? memo,
  }) async => Fund.fromJson(
    await _api.post(
      '/api/trips/$tripId/fund/contributions',
      body: {'memberId': memberId, 'amountKrw': amountKrw, 'memo': memo},
    ) as Json,
  );

  Future<Fund> updateFundContribution(
    String tripId,
    String contributionId, {
    required String memberId,
    required int amountKrw,
    required DateTime contributedOn,
    String? memo,
  }) async => Fund.fromJson(
    await _api.put(
      '/api/trips/$tripId/fund/contributions/$contributionId',
      body: {
        'memberId': memberId,
        'amountKrw': amountKrw,
        'contributedOn': dateParam(contributedOn),
        'memo': memo,
      },
    ) as Json,
  );

  Future<Fund> deleteFundContribution(
    String tripId,
    String contributionId,
  ) async => Fund.fromJson(
    await _api.delete('/api/trips/$tripId/fund/contributions/$contributionId')
        as Json,
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
