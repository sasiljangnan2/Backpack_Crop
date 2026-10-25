import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import 'schedule_models.dart';

class ScheduleApi {
  const ScheduleApi(this._api);

  final ApiClient _api;

  Future<List<Schedule>> schedules(String tripId, {DateTime? day}) async =>
      list(
        await _api.get(
          '/api/trips/$tripId/schedules',
          query: {'day': day == null ? null : dateParam(day)},
        ),
        Schedule.fromJson,
      );

  Future<Schedule> create(
    String tripId, {
    required DateTime day,
    required TimeOfDay start,
    required TimeOfDay end,
    required String title,
    String? placeText,
    String? memo,
    ReservationStatus reservation = ReservationStatus.none,
    bool locked = false,
  }) async => Schedule.fromJson(
    await _api.post(
      '/api/trips/$tripId/schedules',
      body: {
        'day': dateParam(day),
        'startTime': timeParam(start),
        'endTime': timeParam(end),
        'title': title,
        'placeText': placeText,
        'memo': memo,
        'reservationStatus': enumName(reservation),
        'isLocked': locked,
      },
    ) as Json,
  );

  /// 보낸 값만 바뀐다. [placeText]·[memo]는 빈 문자열이면 지워진다.
  Future<Schedule> update(
    String tripId,
    String scheduleId, {
    required int version,
    DateTime? day,
    TimeOfDay? start,
    TimeOfDay? end,
    String? title,
    String? placeText,
    String? memo,
    ReservationStatus? reservation,
    bool? locked,
  }) async => Schedule.fromJson(
    await _api.patch(
      '/api/trips/$tripId/schedules/$scheduleId',
      body: {
        'version': version,
        'day': ?(day == null ? null : dateParam(day)),
        'startTime': ?(start == null ? null : timeParam(start)),
        'endTime': ?(end == null ? null : timeParam(end)),
        'title': ?title,
        'placeText': ?placeText,
        'memo': ?memo,
        'reservationStatus': ?(reservation == null
            ? null
            : enumName(reservation)),
        'isLocked': ?locked,
      },
    ) as Json,
  );

  Future<void> delete(String tripId, String scheduleId) =>
      _api.delete('/api/trips/$tripId/schedules/$scheduleId');

  Future<Schedule> recordActivity(
    String tripId,
    String scheduleId, {
    required TimeOfDay start,
    required TimeOfDay end,
  }) async => Schedule.fromJson(
    await _api.put(
      '/api/trips/$tripId/schedules/$scheduleId/activity',
      body: {
        'actualStartTime': timeParam(start),
        'actualEndTime': timeParam(end),
      },
    ) as Json,
  );

  Future<void> cancelActivity(String tripId, String scheduleId) =>
      _api.delete('/api/trips/$tripId/schedules/$scheduleId/activity');

  Future<TodaySummary> today(String tripId) async =>
      TodaySummary.fromJson(await _api.get('/api/trips/$tripId/today') as Json);

  // ---- 투표

  Future<List<Poll>> polls(String tripId) async =>
      list(await _api.get('/api/trips/$tripId/polls'), Poll.fromJson);

  Future<Poll> poll(String tripId, String pollId) async =>
      Poll.fromJson(await _api.get('/api/trips/$tripId/polls/$pollId') as Json);

  Future<Poll> createPoll(
    String tripId, {
    required String title,
    required DateTime slotDate,
    required TimeOfDay slotStart,
    required TimeOfDay slotEnd,
    DateTime? deadlineAt,
    required List<({String label, String? memo})> options,
  }) async => Poll.fromJson(
    await _api.post(
      '/api/trips/$tripId/polls',
      body: {
        'title': title,
        'slotDate': dateParam(slotDate),
        'slotStart': timeParam(slotStart),
        'slotEnd': timeParam(slotEnd),
        'deadlineAt': deadlineAt?.toUtc().toIso8601String(),
        'options': [
          for (final option in options)
            {'label': option.label, 'memo': option.memo},
        ],
      },
    ) as Json,
  );

  Future<Poll> vote(String tripId, String pollId, String optionId) async =>
      Poll.fromJson(
        await _api.put(
          '/api/trips/$tripId/polls/$pollId/votes/me',
          body: {'optionId': optionId},
        ) as Json,
      );

  Future<void> cancelVote(String tripId, String pollId) =>
      _api.delete('/api/trips/$tripId/polls/$pollId/votes/me');

  Future<Poll> closePoll(
    String tripId,
    String pollId, {
    String? selectedOptionId,
  }) async => Poll.fromJson(
    await _api.post(
      '/api/trips/$tripId/polls/$pollId/close',
      body: {'selectedOptionId': selectedOptionId},
    ) as Json,
  );

  Future<void> deletePoll(String tripId, String pollId) =>
      _api.delete('/api/trips/$tripId/polls/$pollId');
}
