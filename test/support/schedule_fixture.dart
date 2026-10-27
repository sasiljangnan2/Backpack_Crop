import 'package:backpack/core/network/api_exception.dart';
import 'package:backpack/features/trip/data/trip_repository.dart';
import 'package:backpack/features/schedule/data/schedule_models.dart';
import 'package:backpack/features/schedule/data/schedule_repository.dart';
import 'package:backpack/features/schedule/data/memory_schedule_repository.dart';

TripDetail scheduleTrip({
  String id = 'trip-a',
  TripRole role = TripRole.host,
}) => TripDetail(
  id: id,
  name: '오사카 여행',
  destination: '일본 오사카',
  startDate: '2026-11-01',
  endDate: '2026-11-03',
  currencyCode: 'JPY',
  inviteCode: 'ABCD1234',
  myMemberId: 'member-a',
  myRole: role,
  createdAt: DateTime.utc(2026, 10, 27),
);
MemoryScheduleRepository memorySchedules({
  bool hasSamples = true,
  TripRole role = TripRole.host,
}) => MemoryScheduleRepository(
  trip: scheduleTrip(role: role),
  author: const ScheduleAuthor(memberId: 'member-a', name: '여행자'),
  hasSamples: hasSamples,
);

class ScheduleRepositoryWrapper implements ScheduleRepository {
  ScheduleRepositoryWrapper(this.delegate);
  final ScheduleRepository delegate;
  bool hasLoadError = false, hasConflict = false;
  int createCalls = 0;
  @override
  Future<List<ScheduleRecord>> list() {
    if (hasLoadError) {
      return Future.error(const ApiException.network());
    }
    return delegate.list();
  }

  @override
  Future<ScheduleRecord> create(ScheduleDraft draft) {
    createCalls++;
    return delegate.create(draft);
  }

  @override
  Future<ScheduleRecord> update(ScheduleRecord record, ScheduleDraft draft) {
    if (hasConflict) {
      return Future.error(
        const ApiException(status: 409, code: 'CONFLICT', message: '변경됨'),
      );
    }
    return delegate.update(record, draft);
  }

  @override
  Future<ScheduleRecord> setLocked(
    ScheduleRecord record, {
    required bool isLocked,
  }) => delegate.setLocked(record, isLocked: isLocked);
  @override
  Future<void> delete(ScheduleRecord record) => delegate.delete(record);
}
