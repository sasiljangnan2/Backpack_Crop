import '../../../core/network/api_client.dart';
import 'settlement_models.dart';

abstract interface class SettlementRepository {
  Future<SettlementSnapshot> load();
}

class ApiSettlementRepository implements SettlementRepository {
  const ApiSettlementRepository(this.api, this.tripId);
  final ApiClient api;
  final String tripId;
  @override
  Future<SettlementSnapshot> load() async => SettlementSnapshot.fromJson(
    await api.get('/api/trips/${Uri.encodeComponent(tripId)}/settlement')
        as Map<String, Object?>,
  );
}
