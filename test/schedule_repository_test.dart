import 'dart:convert';

import 'package:backpack/core/network/api_client.dart';
import 'package:backpack/core/network/api_exception.dart';
import 'package:backpack/core/network/session_tokens.dart';
import 'package:backpack/features/schedule/data/schedule_models.dart';
import 'package:backpack/features/schedule/data/schedule_repository.dart';
import 'package:backpack/features/schedule/presentation/schedule_controller.dart';
import 'package:backpack/features/schedule/presentation/schedule_previews.dart';
import 'package:backpack/features/trip/data/trip_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_trip_fixture.dart';
import 'support/schedule_fixture.dart';

void main() {
  test('Schedule API preserves calendar dates, version and lock-only request bodies', () async {
    final sample = (await memorySchedules().list()).first;
    final requests = <http.Request>[];
    final store = MemorySessionStore()
      ..current = const SessionTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
      );
    final api = ApiClient(
      store: store,
      baseUrl: 'http://fixture',
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer access');
        if (request.method == 'GET') {
          return jsonResponse(200, [sample.toJson()]);
        }
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return jsonResponse(
          request.method == 'POST' ? 201 : 200,
          sample.toJson(),
        );
      }),
    );
    addTearDown(api.close);
    final repo = ApiScheduleRepository(api, 'trip-a');
    expect((await repo.list()).single.startTime, '09:00');
    const draft = ScheduleDraft(
      day: '2026-11-02',
      startTime: '13:00',
      endTime: '14:00',
      title: '산책',
    );
    await repo.create(draft);
    await repo.update(sample, draft);
    await repo.setLocked(sample, isLocked: true);
    await repo.delete(sample);
    final create = jsonDecode(requests[1].body) as Map<String, Object?>;
    expect(create, {
      'day': '2026-11-02',
      'startTime': '13:00',
      'endTime': '14:00',
      'title': '산책',
      'placeText': null,
      'memo': null,
      'reservationStatus': 'NONE',
    });
    final update = jsonDecode(requests[2].body) as Map<String, Object?>;
    expect(update['version'], sample.version);
    expect(update['placeText'], '');
    expect(update['memo'], '');
    expect(jsonDecode(requests[3].body), {
      'version': sample.version,
      'isLocked': true,
    });
    expect(requests[4].body, isEmpty);
    final response = {
      ...sample.toJson(),
      'startTime': '09:00:00',
      'endTime': '10:00:00',
    };
    expect(ScheduleRecord.fromJson(response).day, '2026-11-01');
    expect(ScheduleRecord.fromJson(response).startTime, '09:00');
  });

  test(
    'Overlap ignores another day, adjacency and the record being edited',
    () async {
      final records = await memorySchedules().list();
      const adjacent = ScheduleDraft(
        day: '2026-11-01',
        startTime: '10:00',
        endTime: '11:00',
        title: '산책',
      );
      const overlap = ScheduleDraft(
        day: '2026-11-01',
        startTime: '09:30',
        endTime: '10:30',
        title: '산책',
      );
      const otherDay = ScheduleDraft(
        day: '2026-11-02',
        startTime: '09:30',
        endTime: '10:30',
        title: '산책',
      );
      expect(overlappingSchedules(adjacent, records), isEmpty);
      expect(
        overlappingSchedules(overlap, records).single.id,
        records.first.id,
      );
      expect(overlappingSchedules(otherDay, records), isEmpty);
      expect(
        overlappingSchedules(overlap, records, excludingId: records.first.id),
        isEmpty,
      );
    },
  );

  test(
    'Fixed schedules reject edits and deletion; unlock increments version',
    () async {
      final repo = memorySchedules();
      final locked = (await repo.list()).last;
      await expectLater(
        repo.update(locked, locked.draft),
        throwsA(isA<ApiException>()),
      );
      await expectLater(repo.delete(locked), throwsA(isA<ApiException>()));
      final unlocked = await repo.setLocked(locked, isLocked: false);
      expect(unlocked.version, locked.version + 1);
      await expectLater(
        repo.update(locked, locked.draft),
        throwsA(isA<ApiException>()),
      );
      await repo.delete(unlocked);
      expect(await repo.list(), hasLength(1));
    },
  );

  test(
    'Selected day follows saved edits while failed changes preserve the list',
    () async {
      final wrapper = ScheduleRepositoryWrapper(memorySchedules());
      final controller = ScheduleController(
        repository: wrapper,
        trip: scheduleTrip(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      final current = controller.items.first;
      const moved = ScheduleDraft(
        day: '2026-11-02',
        startTime: '09:00',
        endTime: '10:00',
        title: '바뀐 일정',
      );
      wrapper.hasConflict = true;
      await expectLater(
        controller.save(moved, current: current),
        throwsA(isA<ApiException>()),
      );
      expect(controller.all.first.title, current.title);
      wrapper.hasConflict = false;
      await controller.save(moved, current: current);
      expect(controller.day, '2026-11-02');
      expect(controller.items.single.title, '바뀐 일정');
      expect(controller.all, hasLength(2));
    },
  );

  test(
    'Preview schedules are isolated by trip and guests cannot mutate them',
    () async {
      final cache = SchedulePreviews();
      final first = cache.forTrip(scheduleTrip(), []),
          second = cache.forTrip(scheduleTrip(id: 'trip-b'), []);
      final item = (await first.list()).first;
      await first.delete(item);
      expect(await first.list(), hasLength(1));
      expect(await second.list(), hasLength(2));
      final guest = memorySchedules(role: TripRole.guest);
      await expectLater(guest.create(item.draft), throwsA(isA<ApiException>()));
    },
  );
}
