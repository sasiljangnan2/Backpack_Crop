import 'package:backpack/core/app_dependencies.dart';
import 'package:backpack/features/schedule/presentation/schedule_screen.dart';
import 'package:backpack/features/schedule/presentation/schedule_strings.dart';
import 'package:backpack/features/trip/data/trip_repository.dart';
import 'package:backpack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_trip_fixture.dart';
import 'support/schedule_fixture.dart';

void compact(WidgetTester tester, {double scale = 1}) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget app(Widget home, {double scale = 1}) => MaterialApp(
  locale: const Locale('ko', 'KR'),
  supportedLocales: const [Locale('ko', 'KR')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);
Future<void> showCard(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    150,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('schedule-list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> pickTime(
  WidgetTester tester,
  String key,
  String hour,
  String minute,
) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextFormField),
  );
  await tester.enterText(fields.first, hour);
  await tester.enterText(fields.last, minute);
  await tester.tap(find.widgetWithText(TextButton, '확인'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Load retry and cancelling a discard preserve the user draft', (
    tester,
  ) async {
    compact(tester);
    final repo = ScheduleRepositoryWrapper(memorySchedules())
      ..hasLoadError = true;
    await tester.pumpWidget(
      app(ScheduleScreen(trip: scheduleTrip(), repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text(ScheduleStrings.retry), findsOneWidget);
    repo.hasLoadError = false;
    await tester.tap(find.text(ScheduleStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text('동네 카페에서 아침'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      '아직 작성 중',
    );
    await tester.tap(find.byTooltip(ScheduleStrings.back));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ScheduleStrings.keepEditing));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('schedule-title')))
          .controller!
          .text,
      '아직 작성 중',
    );
    expect(repo.createCalls, 0);
    await tester.tap(find.byTooltip(ScheduleStrings.back));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ScheduleStrings.leave));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('schedule-add')), findsOneWidget);
    expect(await repo.list(), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Date switching, save, edit and confirmed deletion keep the daily list correct',
    (tester) async {
      compact(tester);
      final repo = memorySchedules();
      await tester.pumpWidget(
        app(
          ScheduleScreen(
            trip: scheduleTrip(),
            repository: repo,
            isPreview: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-11-02')));
      await tester.pumpAndSettle();
      expect(find.text(ScheduleStrings.empty), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(find.text(ScheduleStrings.nameError), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        '미술관 관람',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(find.text('미술관 관람'), findsOneWidget);
      expect((await repo.list()).last.day, '2026-11-02');
      await showCard(tester, '미술관 관람');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, ScheduleStrings.edit),
      );
      await tester.tap(find.widgetWithText(FilledButton, ScheduleStrings.edit));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        '미술관 관람 수정',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(await repo.list(), hasLength(3));
      await showCard(tester, '미술관 관람 수정');
      await tester.ensureVisible(
        find.widgetWithText(TextButton, ScheduleStrings.delete),
      );
      await tester.tap(find.widgetWithText(TextButton, ScheduleStrings.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, ScheduleStrings.cancel));
      await tester.pumpAndSettle();
      expect(await repo.list(), hasLength(3));
      await showCard(tester, '미술관 관람 수정');
      await tester.ensureVisible(
        find.widgetWithText(TextButton, ScheduleStrings.delete),
      );
      await tester.tap(find.widgetWithText(TextButton, ScheduleStrings.delete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, ScheduleStrings.delete),
      );
      await tester.pumpAndSettle();
      expect(await repo.list(), hasLength(2));
      expect(find.text(ScheduleStrings.empty), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Time reversal cannot save; overlaps require explicit acknowledgement',
    (tester) async {
      compact(tester);
      final repo = ScheduleRepositoryWrapper(memorySchedules());
      await tester.pumpWidget(
        app(ScheduleScreen(trip: scheduleTrip(), repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        '쇼핑',
      );
      await pickTime(tester, 'schedule-start', '13', '00');
      expect(find.text(ScheduleStrings.timeError), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(repo.createCalls, 0);
      await pickTime(tester, 'schedule-start', '09', '30');
      await pickTime(tester, 'schedule-end', '10', '30');
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(find.text(ScheduleStrings.overlapTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, ScheduleStrings.cancel));
      await tester.pumpAndSettle();
      expect(repo.createCalls, 0);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('schedule-title')))
            .controller!
            .text,
        '쇼핑',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, ScheduleStrings.overlapSave),
      );
      await tester.pumpAndSettle();
      expect(repo.createCalls, 1);
      expect(await repo.list(), hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Locked and guest views expose their status and prevent destructive actions',
    (tester) async {
      final repo = memorySchedules();
      await tester.pumpWidget(
        app(ScheduleScreen(trip: scheduleTrip(), repository: repo)),
      );
      await tester.pumpAndSettle();
      await showCard(tester, '함께하는 점심');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, ScheduleStrings.edit),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, ScheduleStrings.delete),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, ScheduleStrings.unlock),
      );
      await tester.pumpAndSettle();
      expect((await repo.list()).last.isLocked, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        app(
          ScheduleScreen(
            trip: scheduleTrip(role: TripRole.guest),
            repository: memorySchedules(role: TripRole.guest),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-add')), findsNothing);
      await showCard(tester, '동네 카페에서 아침');
      expect(
        find.widgetWithText(FilledButton, ScheduleStrings.edit),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Conflict preserves input and refresh loads current data only after confirmation',
    (tester) async {
      compact(tester);
      final repo = ScheduleRepositoryWrapper(memorySchedules());
      await tester.pumpWidget(
        app(ScheduleScreen(trip: scheduleTrip(), repository: repo)),
      );
      await tester.pumpAndSettle();
      await showCard(tester, '동네 카페에서 아침');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, ScheduleStrings.edit),
      );
      await tester.tap(find.widgetWithText(FilledButton, ScheduleStrings.edit));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        '내가 바꾼 제목',
      );
      repo.hasConflict = true;
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(find.text(ScheduleStrings.conflict), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('schedule-title')))
            .controller!
            .text,
        '내가 바꾼 제목',
      );
      await tester.ensureVisible(find.text(ScheduleStrings.latestAction));
      await tester.tap(find.text(ScheduleStrings.latestAction));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, ScheduleStrings.latestLoad),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('schedule-title')))
            .controller!
            .text,
        '동네 카페에서 아침',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Large text and keyboard retain the primary action and minimum touch sizes',
    (tester) async {
      compact(tester);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(
        app(
          ScheduleScreen(trip: scheduleTrip(), repository: memorySchedules()),
          scale: 1.4,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('schedule-add'))).height,
        greaterThanOrEqualTo(54),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('schedule-day-2026-11-01')))
            .width,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byKey(const ValueKey('schedule-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        '산책',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('schedule-save'))).bottom,
        lessThanOrEqualTo(440),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Travel preview opens the schedule screen without server requests',
    (tester) async {
      compact(tester);
      final fixture = AuthTripFixture();
      final deps = AppDependencies.create(
        store: MemorySessionStore(),
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('trip-preview')));
      await tester.tap(find.byKey(const ValueKey('trip-preview')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('친구들과 오사카'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-open')));
      await tester.pumpAndSettle();
      expect(find.text(ScheduleStrings.title), findsOneWidget);
      expect(find.text(ScheduleStrings.preview), findsOneWidget);
      expect(fixture.loginCalls, 0);
      expect(fixture.createCalls, 0);
    },
  );
}
