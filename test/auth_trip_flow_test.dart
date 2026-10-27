import 'package:backpack/core/app_dependencies.dart';
import 'package:backpack/core/network/session_tokens.dart';
import 'package:backpack/features/user/presentation/auth_controller.dart';
import 'package:backpack/features/trip/presentation/trip_strings.dart';
import 'package:backpack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_trip_fixture.dart';

void compact(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 160,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}

Future<void> login(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, '로그인'));
  await tester.tap(find.widgetWithText(FilledButton, '로그인'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('login-email')),
    'traveler@example.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    'backpack123',
  );
  await tester.tap(find.byKey(const ValueKey('login-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Signup, login, create travel and preview expenses use the same server member identity',
    (tester) async {
      compact(tester);
      final fixture = AuthTripFixture();
      final store = MemorySessionStore();
      final deps = AppDependencies.create(
        store: store,
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('회원가입'));
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '여행자');
      await tester.enterText(fields.at(1), 'traveler@example.com');
      await tester.enterText(fields.at(2), 'backpack123');
      await tester.enterText(fields.at(3), 'backpack123');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '가입하고 시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('가입이 완료됐어요. 로그인해 주세요.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('login-email')))
            .controller!
            .text,
        'traveler@example.com',
      );
      expect(store.tokens, isNull);
      expect(fixture.signupCalls, 1);
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'backpack123',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('아직 여행이 없어요'), findsOneWidget);
      expect(deps.auth.status, SessionStatus.signedIn);
      await tester.tap(find.byKey(const ValueKey('trip-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('trip-name')),
        '친구들과 오사카',
      );
      await tester.enterText(
        find.byKey(const ValueKey('trip-destination')),
        '일본 오사카',
      );
      await tester.tap(find.byKey(const ValueKey('trip-dates')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('14').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '날짜 선택').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trip-create-submit')));
      await tester.pumpAndSettle();
      expect(find.text('친구들과 오사카'), findsOneWidget);
      expect(find.text('ABCD1234'), findsOneWidget);
      expect(find.text('여행자'), findsOneWidget);
      expect(fixture.createCalls, 1);
      expect(fixture.lastTripRequest!.keys.toSet(), {
        'name',
        'destination',
        'startDate',
        'endDate',
        'currencyCode',
      });
      final start = fixture.lastTripRequest!['startDate'] as String;
      final end = fixture.lastTripRequest!['endDate'] as String;
      expect(start.endsWith('-10'), isTrue);
      expect(end.endsWith('-14'), isTrue);
      await reveal(tester, find.text('이 여행의 경비 미리보기'));
      await tester.tap(find.text('이 여행의 경비 미리보기'));
      await tester.pumpAndSettle();
      expect(find.text('등록된 지출이 없어요'), findsOneWidget);
      expect(find.text('친구들과 오사카'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('expense-add')));
      await tester.pumpAndSettle();
      expect(find.text('여행자'), findsOneWidget);
      expect(find.text('성진'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Login rejection stays on the form; logout clears the persisted session',
    (tester) async {
      compact(tester);
      tester.view.physicalSize = const Size(320, 568);
      final fixture = AuthTripFixture()..hasAccount = true;
      final store = MemorySessionStore();
      final deps = AppDependencies.create(
        store: store,
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, '로그인'));
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'traveler@example.com',
      );
      await reveal(tester, find.byKey(const ValueKey('login-password')));
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'wrong',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('login-submit'))).bottom,
        lessThanOrEqualTo(368),
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(store.tokens, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'backpack123',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
      await tester.pumpAndSettle();
      expect(store.tokens, isNull);
      expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'App recreation restores login; a failed trip request can be retried',
    (tester) async {
      final fixture = AuthTripFixture()
        ..hasAccount = true
        ..hasTripError = true;
      final store = MemorySessionStore()
        ..current = const SessionTokens(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
        );
      final deps = AppDependencies.create(
        store: store,
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(store.tokens!.refreshToken, 'refresh-2');
      fixture.hasTripError = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('아직 여행이 없어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      deps.dispose();
      final restarted = AppDependencies.create(
        store: store,
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(restarted.dispose);
      await tester.pumpWidget(MyApp(dependencies: restarted));
      await tester.pumpAndSettle();
      expect(find.text('내 여행'), findsOneWidget);
      expect(fixture.refreshCalls, 2);
      expect(fixture.loginCalls, 0);
    },
  );

  testWidgets(
    'Missing dates and invalid trip fields do not create a server trip',
    (tester) async {
      final fixture = AuthTripFixture()..hasAccount = true;
      final deps = AppDependencies.create(
        store: MemorySessionStore(),
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      await login(tester);
      await tester.tap(find.byKey(const ValueKey('trip-create')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trip-create-submit')));
      await tester.pumpAndSettle();
      expect(find.text(TripStrings.invalidName), findsOneWidget);
      expect(find.text(TripStrings.dateRequired), findsOneWidget);
      expect(fixture.createCalls, 0);
    },
  );

  testWidgets(
    'Preview travel stays isolated from server credentials and existing sample trips',
    (tester) async {
      compact(tester);
      final fixture = AuthTripFixture();
      final store = MemorySessionStore();
      final deps = AppDependencies.create(
        store: store,
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('trip-preview')));
      await tester.tap(find.byKey(const ValueKey('trip-preview')));
      await tester.pumpAndSettle();
      expect(find.text('샘플 여행 · 서버에 저장되지 않아요'), findsOneWidget);
      expect(find.byTooltip('로그아웃'), findsNothing);
      await tester.tap(find.text('친구들과 오사카'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO2026'), findsOneWidget);
      await reveal(tester, find.text('이 여행의 경비 미리보기'));
      await tester.tap(find.text('이 여행의 경비 미리보기'));
      await tester.pumpAndSettle();
      expect(find.text('등록된 지출이 없어요'), findsOneWidget);
      expect(store.tokens, isNull);
      expect(deps.auth.status, SessionStatus.signedOut);
      expect(fixture.loginCalls, 0);
      expect(fixture.createCalls, 0);
      expect(fixture.refreshCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Expired credentials return to welcome and remove the stored session',
    (tester) async {
      final fixture = AuthTripFixture()..hasAccount = true;
      final store = MemorySessionStore()
        ..current = const SessionTokens(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
        );
      final deps = AppDependencies.create(
        store: store,
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      expect(find.text('내 여행'), findsOneWidget);
      fixture.access = 'revoked';
      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(store.tokens, isNull);
      expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Invalid saved refresh token opens welcome without a stale notice crash',
    (tester) async {
      final fixture = AuthTripFixture();
      final store = MemorySessionStore()
        ..current = const SessionTokens(
          accessToken: 'expired',
          refreshToken: 'expired-r',
        );
      final deps = AppDependencies.create(
        store: store,
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      expect(store.tokens, isNull);
      expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
