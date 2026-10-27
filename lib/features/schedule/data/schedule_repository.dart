import '../../../core/network/api_client.dart';
import 'schedule_models.dart';

abstract interface class ScheduleRepository {
  Future<List<ScheduleRecord>> list();
  Future<ScheduleRecord> create(ScheduleDraft draft);
  Future<ScheduleRecord> update(ScheduleRecord current, ScheduleDraft draft);
  Future<ScheduleRecord> setLocked(
    ScheduleRecord current, {
    required bool isLocked,
  });
  Future<void> delete(ScheduleRecord current);
}

class ApiScheduleRepository implements ScheduleRepository {
  const ApiScheduleRepository(this.api, this.tripId);
  final ApiClient api;
  final String tripId;
  String get _path => '/api/trips/${Uri.encodeComponent(tripId)}/schedules';
  @override
  Future<List<ScheduleRecord>> list() async =>
      (await api.get(_path) as List<Object?>)
          .map((item) => ScheduleRecord.fromJson(item as Map<String, Object?>))
          .toList();
  @override
  Future<ScheduleRecord> create(ScheduleDraft draft) async =>
      ScheduleRecord.fromJson(
        await api.post(_path, body: draft.toJson()) as Map<String, Object?>,
      );
  @override
  Future<ScheduleRecord> update(
    ScheduleRecord current,
    ScheduleDraft draft,
  ) async => ScheduleRecord.fromJson(
    await api.patch(
      '$_path/${Uri.encodeComponent(current.id)}',
      body: {
        ...draft.toJson(),
        'placeText': draft.placeText?.trim() ?? '',
        'memo': draft.memo?.trim() ?? '',
        'version': current.version,
      },
    ) as Map<String, Object?>,
  );
  @override
  Future<ScheduleRecord> setLocked(
    ScheduleRecord current, {
    required bool isLocked,
  }) async => ScheduleRecord.fromJson(
    await api.patch(
      '$_path/${Uri.encodeComponent(current.id)}',
      body: {'version': current.version, 'isLocked': isLocked},
    ) as Map<String, Object?>,
  );
  @override
  Future<void> delete(ScheduleRecord current) async {
    await api.delete('$_path/${Uri.encodeComponent(current.id)}');
  }
}
