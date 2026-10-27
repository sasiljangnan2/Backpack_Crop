import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:backpack/core/app_dependencies.dart';
import 'package:backpack/core/network/api_client.dart';
import 'package:backpack/core/network/api_exception.dart';
import 'package:backpack/core/network/session_tokens.dart';
import 'package:backpack/core/network/token_storage.dart';
import 'package:backpack/features/user/presentation/auth_controller.dart';
import 'package:backpack/features/trip/data/trip_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_trip_fixture.dart';

void main() {
  test(
    'Signup response is a user; login response is only a token pair',
    () async {
      final fixture = AuthTripFixture();
      final store = MemorySessionStore();
      final deps = AppDependencies.create(
        store: store,
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await deps.auth.restore();
      final user = await deps.auth.repository.signup(
        email: ' traveler@example.com ',
        password: 'backpack123',
        name: ' 여행자 ',
      );
      expect(user.email, 'traveler@example.com');
      expect(store.tokens, isNull);
      expect(fixture.loginCalls, 0);
      await deps.auth.login(user.email, 'backpack123');
      expect(store.tokens!.accessToken, 'access-1');
      expect(deps.auth.status, SessionStatus.signedIn);
      expect(fixture.loginCalls, 1);
    },
  );

  test('Persisted session restores by rotating tokens without depending on users/me', () async {
    final fixture = AuthTripFixture();
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
    await deps.auth.restore();
    expect(deps.auth.status, SessionStatus.signedIn);
    expect(store.tokens!.refreshToken, 'refresh-2');
    expect(fixture.refreshCalls, 1);
  });

  test(
    'Network failure during restore keeps the saved session retryable',
    () async {
      final store = MemorySessionStore()
        ..current = const SessionTokens(accessToken: 'a', refreshToken: 'r');
      final deps = AppDependencies.create(
        store: store,
        client: MockClient((_) async => throw const SocketException('offline')),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await deps.auth.restore();
      expect(deps.auth.status, SessionStatus.signedIn);
      expect(store.tokens!.refreshToken, 'r');
    },
  );

  test('Concurrent expired requests share one refresh and retry with the new access token', () async {
    final store = MemorySessionStore()
      ..current = const SessionTokens(accessToken: 'old', refreshToken: 'r1');
    final gate = Completer<void>();
    final started = Completer<void>();
    var refreshCalls = 0;
    final api = ApiClient(
      store: store,
      baseUrl: 'http://fixture',
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/reissue') {
          refreshCalls++;
          started.complete();
          await gate.future;
          return jsonResponse(200, {
            'accessToken': 'new',
            'refreshToken': 'r2',
          });
        }
        if (request.headers['Authorization'] == 'Bearer old') {
          return jsonResponse(401, {'code': 'TOKEN_EXPIRED', 'message': '만료'});
        }
        return jsonResponse(200, []);
      }),
    );
    addTearDown(api.close);
    final requests = Future.wait([
      api.get('/api/trips'),
      api.get('/api/trips'),
    ]);
    await started.future;
    gate.complete();
    await requests;
    expect(refreshCalls, 1);
    expect(store.tokens!.refreshToken, 'r2');
  });

  test('Invalid refresh clears the session; refresh completed after logout cannot restore it', () async {
    final store = MemorySessionStore()
      ..current = const SessionTokens(accessToken: 'a', refreshToken: 'r');
    var expired = 0;
    final invalid = ApiClient(
      store: store,
      baseUrl: 'http://fixture',
      client: MockClient(
        (_) async =>
            jsonResponse(401, {'code': 'UNAUTHORIZED', 'message': '만료'}),
      ),
    )..onSessionExpired = () => expired++;
    addTearDown(invalid.close);
    await expectLater(invalid.refreshSession(), throwsA(isA<ApiException>()));
    expect(store.tokens, isNull);
    expect(expired, 1);
    store.current = const SessionTokens(accessToken: 'a', refreshToken: 'r');
    final response = Completer<http.Response>();
    final pending = ApiClient(
      store: store,
      baseUrl: 'http://fixture',
      client: MockClient((_) => response.future),
    );
    addTearDown(pending.close);
    final rotating = pending.refreshSession();
    await store.clear();
    response.complete(
      jsonResponse(200, {'accessToken': 'new', 'refreshToken': 'new-r'}),
    );
    await rotating;
    expect(store.tokens, isNull);
  });

  test('Secure storage saves both tokens together and a fresh instance can load them', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final first = TokenStorage();
    await first.save(
      const SessionTokens(accessToken: 'access', refreshToken: 'refresh'),
    );
    final second = TokenStorage();
    await second.load();
    expect(second.tokens!.accessToken, 'access');
    expect(second.tokens!.refreshToken, 'refresh');
    await second.clear();
    final third = TokenStorage();
    await third.load();
    expect(third.tokens, isNull);
  });

  test('Storage write failure never reports a successful login', () async {
    final store = MemorySessionStore()..hasSaveError = true;
    final fixture = AuthTripFixture()..hasAccount = true;
    final deps = AppDependencies.create(
      store: store,
      client: fixture.client(),
      baseUrl: 'http://fixture',
    );
    addTearDown(deps.dispose);
    await deps.auth.restore();
    await expectLater(
      deps.auth.login('traveler@example.com', 'backpack123'),
      throwsStateError,
    );
    expect(deps.auth.status, SessionStatus.signedOut);
    expect(store.tokens, isNull);
  });

  test('Travel requests preserve date-only strings and match the actual trip branch DTO', () async {
    final fixture = AuthTripFixture();
    final store = MemorySessionStore()
      ..current = const SessionTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );
    final api = ApiClient(
      store: store,
      client: fixture.client(),
      baseUrl: 'http://fixture',
    );
    addTearDown(api.close);
    final request = TripCreateRequest(
      name: ' 오사카 여행 ',
      destination: ' 일본 오사카 ',
      startDate: '2026-11-01',
      endDate: '2026-11-05',
      currencyCode: 'JPY',
    );
    final detail = await ApiTripRepository(api).create(request);
    expect(fixture.lastTripRequest, {
      'name': '오사카 여행',
      'destination': '일본 오사카',
      'startDate': '2026-11-01',
      'endDate': '2026-11-05',
      'currencyCode': 'JPY',
    });
    expect(detail.myMemberId, AuthTripFixture.memberId);
    expect(detail.startDate, '2026-11-01');
    expect(
      TripCreateRequest.fromJson(
        jsonDecode(jsonEncode(request.toJson())) as Map<String, Object?>,
      ).toJson(),
      request.toJson(),
    );
  });

  test(
    'Logout sends a valid access token and revokes the rotated refresh token',
    () async {
      final fixture = AuthTripFixture()..hasAccount = true;
      final store = MemorySessionStore();
      var didRevoke = false;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/logout') {
          expect(request.headers['Authorization'], 'Bearer ${fixture.access}');
          expect(jsonDecode(request.body), {'refreshToken': fixture.refresh});
          expect(fixture.refreshCalls, 1);
          didRevoke = true;
        }
        return fixture.handle(request);
      });
      final deps = AppDependencies.create(
        store: store,
        client: client,
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await deps.auth.restore();
      await deps.auth.login('traveler@example.com', 'backpack123');
      await deps.auth.logout();
      expect(didRevoke, isTrue);
      expect(store.tokens, isNull);
      expect(deps.auth.status, SessionStatus.signedOut);
    },
  );
}
