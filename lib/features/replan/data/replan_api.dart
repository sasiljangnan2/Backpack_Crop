import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../schedule/data/schedule_models.dart';
import 'replan_models.dart';

/// BP-AI-002 · 003 AI 일정 재구성
class ReplanApi {
  const ReplanApi(this._api);

  final ApiClient _api;

  /// [currentName]이 없으면 서버가 마지막으로 끝낸 일정의 장소를 현재 장소로 본다
  Future<ReplanResult> recommend(
    String tripId, {
    required List<String> scheduleIds,
    required Set<ReplanCondition> conditions,
    String? currentName,
    double? currentLat,
    double? currentLng,
    bool fromGps = false,
  }) async => ReplanResult.fromJson(
    await _api.post(
      '/api/trips/$tripId/replan',
      // 서버는 AI를 25초까지 기다리고 그다음 기본 추천으로 답한다. 그보다 넉넉히 기다린다
      timeout: const Duration(seconds: 45),
      body: {
        'scheduleIds': scheduleIds,
        'conditions': [for (final c in conditions) c.code],
        if (currentName != null)
          'currentPlace': {
            'name': currentName,
            'lat': currentLat,
            'lng': currentLng,
            'fromGps': fromGps,
          },
      },
    ) as Json,
  );

  /// 고른 안을 적용하고 그날 일정 전체를 돌려받는다
  Future<List<Schedule>> apply(
    String tripId, {
    required String requestId,
    required PlanKey plan,
  }) async => list(
    await _api.post(
      '/api/trips/$tripId/replan/apply',
      body: {'requestId': requestId, 'planKey': plan.code},
    ),
    Schedule.fromJson,
  );
}
