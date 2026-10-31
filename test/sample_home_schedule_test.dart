import 'package:backpack/app.dart';
import 'package:backpack/core/app_dependencies.dart';
import 'package:backpack/features/schedule/data/sample_home_schedule.dart';
import 'package:backpack/features/schedule/data/schedule_models.dart';
import 'package:backpack/features/schedule/presentation/schedule_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_trip_fixture.dart';

void main() {
  test(
    'Home schedule previews are isolated and a fresh session resets them',
    () async {
      final first = SampleHomeSchedule(), second = SampleHomeSchedule();
      await first.repository.create(
        ScheduleDraft(
          day: first.trip.startDate,
          startTime: '15:00',
          endTime: '16:00',
          title: '홈 샘플 일정',
        ),
      );
      expect(await first.repository.list(), hasLength(3));
      expect(await second.repository.list(), hasLength(2));
      expect(await SampleHomeSchedule().repository.list(), hasLength(2));
    },
  );

  testWidgets(
    'Sample home opens editable schedules and preserves selected date across tabs',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = AuthTripFixture();
      final deps = AppDependencies.create(
        store: MemorySessionStore(),
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      final home = find.text('샘플 여행 홈 둘러보기');
      await tester.ensureVisible(home);
      await tester.tap(home);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('일정 전체 ›'));
      await tester.tap(find.text('일정 전체 ›'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-add')), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-10-03')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        '홈에서 추가한 일정',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(find.text('홈에서 추가한 일정'), findsOneWidget);
      expect(
        tester.getRect(find.byType(SnackBar)).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('schedule-add'))).top,
        ),
      );
      await tester.tap(find.widgetWithText(NavigationDestination, '경비'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('expense-add')), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, '일정'));
      await tester.pumpAndSettle();
      expect(find.text('홈에서 추가한 일정'), findsOneWidget);
      expect(
        find.text(ScheduleStrings.dateLabel('2026-10-03')),
        findsOneWidget,
      );
      await tester.tap(find.text('홈에서 추가한 일정'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, ScheduleStrings.edit),
      );
      await tester.tap(find.widgetWithText(FilledButton, ScheduleStrings.edit));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        '홈 일정 수정 완료',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(find.text('홈 일정 수정 완료'), findsOneWidget);
      expect(find.text('홈에서 추가한 일정'), findsNothing);
      expect(fixture.loginCalls, 0);
      expect(fixture.createCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
