import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import 'place_models.dart';

/// 지도용 장소 검색 · 이동 시간 (서버가 OpenStreetMap에 대신 묻고 캐시한다)
class PlaceApi {
  const PlaceApi(this._api);

  final ApiClient _api;

  /// 검색 버튼을 눌렀을 때만 부른다 (공용 검색 서버의 자동완성 금지 정책).
  /// [tripId]를 주면 여행지 근처, [lat]·[lng]를 주면 그 근처를 먼저 보여 준다
  Future<List<Place>> search(
    String query, {
    String? tripId,
    double? lat,
    double? lng,
  }) async => list(
    await _api.get(
      '/api/places/search',
      query: {'q': query, 'tripId': tripId, 'lat': lat, 'lng': lng},
    ),
    Place.fromJson,
  );

  /// 좌표에 있는 장소. 찾지 못하면 null
  Future<Place?> reverse(double lat, double lng) async {
    final json = await _api.get(
      '/api/places/reverse',
      query: {'lat': lat, 'lng': lng},
    );
    return json == null ? null : Place.fromJson(json as Json);
  }

  Future<TravelLeg> travel({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async => TravelLeg.fromJson(
    await _api.get(
      '/api/places/travel',
      query: {
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
      },
    ) as Json,
  );

  Future<DayRoute> dayRoute(String tripId, DateTime day) async =>
      DayRoute.fromJson(
        await _api.get(
          '/api/trips/$tripId/schedules/route',
          query: {'day': dateParam(day)},
        ) as Json,
      );
}
