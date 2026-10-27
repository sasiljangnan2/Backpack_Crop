import '../../../core/network/api_exception.dart';
import '../../trip/data/trip_repository.dart';
import 'schedule_models.dart';
import 'schedule_repository.dart';

class MemoryScheduleRepository implements ScheduleRepository {
  MemoryScheduleRepository({
    required this.trip,
    required this.author,
    bool hasSamples = false,
  }) {
    if (hasSamples) {
      _records.addAll([
        _record(
          'sample-cafe',
          ScheduleDraft(
            day: trip.startDate,
            startTime: '09:00',
            endTime: '10:00',
            title: '동네 카페에서 아침',
            placeText: '숙소 근처 카페',
            memo: '가볍게 아침 먹고 출발해요.',
          ),
        ),
        _record(
          'sample-lunch',
          ScheduleDraft(
            day: trip.startDate,
            startTime: '12:00',
            endTime: '13:00',
            title: '함께하는 점심',
            placeText: '예약한 식당',
            reservationStatus: ReservationStatus.confirmed,
            memo: '예약 시간 10분 전에 도착해요.',
          ),
          isLocked: true,
        ),
      ]);
    }
  }
  final TripDetail trip;
  final ScheduleAuthor author;
  final List<ScheduleRecord> _records = [];
  int _nextId = 0;
  ScheduleRecord _record(
    String id,
    ScheduleDraft draft, {
    bool isLocked = false,
  }) => ScheduleRecord(
    id: id,
    draft: draft,
    createdBy: author,
    version: 0,
    updatedAt: DateTime.now().toUtc(),
    isLocked: isLocked,
  );
  void _requireWrite() {
    if (trip.myRole == TripRole.guest) {
      throw const ApiException(
        status: 403,
        code: 'FORBIDDEN',
        message: '게스트는 일정을 확인할 수만 있어요.',
      );
    }
  }

  void _validate(ScheduleDraft draft) {
    if (draft.day.compareTo(trip.startDate) < 0 ||
        draft.day.compareTo(trip.endDate) > 0 ||
        timeMinutes(draft.endTime) <= timeMinutes(draft.startTime) ||
        draft.title.trim().isEmpty ||
        draft.title.trim().length > 100 ||
        (draft.placeText?.length ?? 0) > 100 ||
        (draft.memo?.length ?? 0) > 500) {
      throw const ApiException(
        status: 400,
        code: 'VALIDATION_ERROR',
        message: '날짜와 시간, 입력 내용을 확인해 주세요.',
      );
    }
  }

  ScheduleRecord _current(ScheduleRecord record) {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      throw const ApiException(
        status: 404,
        code: 'NOT_FOUND',
        message: '일정을 찾을 수 없어요.',
      );
    }
    final current = _records[index];
    if (current.version != record.version) {
      throw const ApiException(
        status: 409,
        code: 'CONFLICT',
        message: '일정이 변경됐어요. 최신 목록을 확인해 주세요.',
      );
    }
    return current;
  }

  @override
  Future<List<ScheduleRecord>> list() async => List.unmodifiable(_records);
  @override
  Future<ScheduleRecord> create(ScheduleDraft draft) async {
    _requireWrite();
    _validate(draft);
    final record = _record('preview-schedule-${_nextId++}', draft);
    _records.add(record);
    return record;
  }

  @override
  Future<ScheduleRecord> update(
    ScheduleRecord current,
    ScheduleDraft draft,
  ) async {
    _requireWrite();
    final old = _current(current);
    _validate(draft);
    if (old.isLocked) {
      throw const ApiException(
        status: 409,
        code: 'CONFLICT',
        message: '고정한 일정은 먼저 고정을 해제해 주세요.',
      );
    }
    final saved = old.changed(draft: draft);
    _records[_records.indexOf(old)] = saved;
    return saved;
  }

  @override
  Future<ScheduleRecord> setLocked(
    ScheduleRecord current, {
    required bool isLocked,
  }) async {
    _requireWrite();
    final old = _current(current);
    final saved = old.changed(isLocked: isLocked);
    _records[_records.indexOf(old)] = saved;
    return saved;
  }

  @override
  Future<void> delete(ScheduleRecord current) async {
    _requireWrite();
    final old = _current(current);
    if (old.isLocked) {
      throw const ApiException(
        status: 409,
        code: 'CONFLICT',
        message: '고정한 일정은 먼저 고정을 해제해 주세요.',
      );
    }
    _records.remove(old);
  }
}
