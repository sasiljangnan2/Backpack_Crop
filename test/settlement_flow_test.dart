import 'package:backpack/app.dart';
import 'package:backpack/features/trip/data/sample_trip_repository.dart';
import 'package:backpack/features/trip/presentation/trip_expense_previews.dart';
import 'package:backpack/features/trip/presentation/trip_overview_screen.dart';
import 'package:http/testing.dart';
import 'package:backpack/core/app_dependencies.dart';
import 'package:backpack/features/settlement/presentation/settlement_screen.dart';
import 'package:backpack/features/settlement/presentation/settlement_strings.dart';
import 'package:backpack/features/settlement/presentation/widgets/settlement_summary_card.dart';
import 'package:backpack/features/settlement/presentation/widgets/settlement_member_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_trip_fixture.dart';
import 'support/settlement_fixture.dart';

Widget app(Widget screen, {double scale = 1}) => MaterialApp(
  key: UniqueKey(),
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
  home: screen,
);
Widget screen(FixtureSettlementRepository repo, {String myId = 'a'}) =>
    SettlementScreen(
      tripName: '함께하는 여행',
      currentMemberId: myId,
      repository: repo,
    );
void compact(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  bool isSettlement = true,
}) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: isSettlement
        ? find
              .descendant(
                of: find.byKey(const ValueKey('settlement-list')),
                matching: find.byType(Scrollable),
              )
              .first
        : find.byType(Scrollable).first,
    maxScrolls: 45,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Server-trip settlement retries the API without replacing errors with preview data',
    (tester) async {
      compact(tester);
      var hasError = true, calls = 0;
      final deps = AppDependencies.create(
        store: MemorySessionStore(),
        baseUrl: 'http://fixture',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/trips/preview-trip-0/settlement');
          calls++;
          return hasError
              ? jsonResponse(500, {
                  'code': 'INTERNAL_SERVER_ERROR',
                  'message': '서버 조회 실패',
                })
              : jsonResponse(200, settlementFixture().toJson());
        }),
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(
        AppScope(
          dependencies: deps,
          child: app(
            TripOverviewScreen(
              tripId: 'preview-trip-0',
              repository: SampleTripRepository(),
              expensePreviews: TripExpensePreviews(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('settlement-open')),
        isSettlement: false,
      );
      await tester.tap(find.byKey(const ValueKey('settlement-open')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('서버 조회 실패'), findsOneWidget);
      expect(find.byKey(const ValueKey('settlement-total')), findsNothing);
      expect(find.text(SettlementStrings.preview), findsNothing);
      hasError = false;
      await tester.tap(find.text(SettlementStrings.retry));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('settlement-total')))
            .data,
        '24,000원',
      );
      expect(find.byKey(const ValueKey('settlement-expenses')), findsNothing);
    },
  );

  testWidgets(
    'Receiving summary, own/all transfers and member detail keep money direction clear',
    (tester) async {
      compact(tester);
      await tester.pumpWidget(
        app(screen(FixtureSettlementRepository(settlementFixture()))),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('settlement-total')))
            .data,
        '24,000원',
      );
      expect(
        find.descendant(
          of: find.byType(SettlementSummaryCard),
          matching: find.text(SettlementStrings.receive),
        ),
        findsOneWidget,
      );
      await reveal(tester, find.byKey(const ValueKey('settlement-filter-all')));
      expect(find.byKey(const ValueKey('settlement-transfer-1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('settlement-filter-all')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('settlement-transfer-1')));
      expect(
        find.byKey(const ValueKey('settlement-transfer-1')),
        findsOneWidget,
      );
      await reveal(tester, find.byKey(const ValueKey('settlement-member-b')));
      await tester.tap(find.byKey(const ValueKey('settlement-member-b')));
      await tester.pumpAndSettle();
      expect(find.text(SettlementStrings.memberTitle('동행 b')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SettlementMemberSheet),
          matching: find.text(SettlementStrings.send),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: find.byType(SettlementMemberSheet),
          matching: find.text(SettlementStrings.receive),
        ),
        findsNothing,
      );
      expect(find.text('2,000원'), findsWidgets);
      expect(find.text('6,000원'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A negative balance is labelled as money to send', (
    tester,
  ) async {
    compact(tester);
    await tester.pumpWidget(
      app(screen(FixtureSettlementRepository(settlementFixture()), myId: 'b')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SettlementSummaryCard),
        matching: find.text(SettlementStrings.send),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('settlement-my-balance')))
          .data,
      '4,000원',
    );
  });

  testWidgets(
    'No expense, no differences and missing member have distinct guidance',
    (tester) async {
      compact(tester);
      await tester.pumpWidget(
        app(
          screen(FixtureSettlementRepository(settlementFixture(isEmpty: true))),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text(SettlementStrings.empty));
      expect(find.text(SettlementStrings.empty), findsOneWidget);
      await tester.pumpWidget(
        app(
          screen(
            FixtureSettlementRepository(settlementFixture(isBalanced: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text(SettlementStrings.noTransfers));
      expect(find.text(SettlementStrings.noTransfers), findsOneWidget);
      expect(find.text(SettlementStrings.empty), findsNothing);
      await tester.pumpWidget(
        app(
          screen(
            FixtureSettlementRepository(settlementFixture()),
            myId: 'missing',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(SettlementStrings.missingMe), findsOneWidget);
      expect(find.byKey(const ValueKey('settlement-my-balance')), findsNothing);
      await reveal(tester, find.byKey(const ValueKey('settlement-filter-all')));
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('settlement-filter-all')),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'Load retry succeeds and failed refresh marks previously loaded amounts',
    (tester) async {
      compact(tester);
      final repo = FixtureSettlementRepository(settlementFixture())
        ..hasError = true;
      await tester.pumpWidget(app(screen(repo)));
      await tester.pumpAndSettle();
      expect(find.text(SettlementStrings.retry), findsOneWidget);
      repo.hasError = false;
      await tester.tap(find.text(SettlementStrings.retry));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settlement-total')), findsOneWidget);
      repo.hasError = true;
      await tester.tap(find.byKey(const ValueKey('settlement-refresh')));
      await tester.pumpAndSettle();
      expect(find.text(SettlementStrings.stale), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('settlement-total')))
            .data,
        '24,000원',
      );
    },
  );

  testWidgets(
    'Long names, large won amounts and enlarged text fit a small screen',
    (tester) async {
      compact(tester);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(
        app(
          screen(
            FixtureSettlementRepository(
              settlementFixture(hasLongNames: true, multiplier: 1234567),
            ),
          ),
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await reveal(tester, find.byKey(const ValueKey('settlement-filter-all')));
      await tester.tap(find.byKey(const ValueKey('settlement-filter-all')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('settlement-member-b')));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('settlement-member-b')))
            .height,
        greaterThan(48),
      );
      await tester.tap(find.byKey(const ValueKey('settlement-member-b')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(SettlementStrings.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SettlementStrings.close));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Preview expense registration refreshes settlement and reuses the same saved record',
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
      await reveal(
        tester,
        find.byKey(const ValueKey('settlement-open')),
        isSettlement: false,
      );
      await tester.tap(find.byKey(const ValueKey('settlement-open')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text(SettlementStrings.empty));
      await tester.tap(find.byKey(const ValueKey('settlement-expenses')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('expense-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('expense-title')),
        '공동 택시',
      );
      await reveal(
        tester,
        find.byKey(const ValueKey('item-name-0')),
        isSettlement: false,
      );
      await tester.enterText(find.byKey(const ValueKey('item-name-0')), '택시');
      await reveal(
        tester,
        find.byKey(const ValueKey('item-amount-0')),
        isSettlement: false,
      );
      await tester.enterText(
        find.byKey(const ValueKey('item-amount-0')),
        '1000',
      );
      await tester.tap(find.byKey(const ValueKey('expense-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '분담 결과 확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('apply-split')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('expense-add')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('settlement-total')))
            .data,
        '9,350원',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('settlement-my-balance')))
            .data,
        '4,675원',
      );
      expect(fixture.loginCalls, 0);
      expect(fixture.createCalls, 0);
    },
  );
}
