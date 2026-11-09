import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import 'trip_models.dart';

class TripApi {
  const TripApi(this._api);

  final ApiClient _api;

  Future<List<TripSummary>> myTrips() async =>
      list(await _api.get('/api/trips'), TripSummary.fromJson);

  Future<TripDetail> trip(String tripId) async =>
      TripDetail.fromJson(await _api.get('/api/trips/$tripId') as Json);

  Future<TripDetail> create({
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String currencyCode,
    required String timeZone,
  }) async => TripDetail.fromJson(
    await _api.post(
      '/api/trips',
      body: {
        'name': name,
        'destination': destination,
        'startDate': dateParam(startDate),
        'endDate': dateParam(endDate),
        'currencyCode': currencyCode,
        'timeZone': timeZone,
      },
    ) as Json,
  );

  Future<TripDetail> update(
    String tripId, {
    String? name,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? currencyCode,
    String? timeZone,
  }) async => TripDetail.fromJson(
    await _api.patch(
      '/api/trips/$tripId',
      body: {
        'name': ?name,
        'destination': ?destination,
        'startDate': ?(startDate == null ? null : dateParam(startDate)),
        'endDate': ?(endDate == null ? null : dateParam(endDate)),
        'currencyCode': ?currencyCode,
        'timeZone': ?timeZone,
      },
    ) as Json,
  );

  Future<void> delete(String tripId) => _api.delete('/api/trips/$tripId');

  Future<TripDetail> join(String inviteCode) async => TripDetail.fromJson(
    await _api.post('/api/trips/join', body: {'inviteCode': inviteCode})
        as Json,
  );

  Future<void> leave(String tripId) =>
      _api.delete('/api/trips/$tripId/members/me');

  Future<void> changePrepaidRate(String tripId, double? rate) => _api.patch(
    '/api/trips/$tripId/members/me/prepaid-rate',
    body: {'prepaidRate': rate},
  );
}
