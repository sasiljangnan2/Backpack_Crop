import 'dart:convert';

import 'package:backpack/core/network/api_client.dart';
import 'package:backpack/core/network/api_exception.dart';
import 'package:backpack/core/network/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(int status, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('액세스 토큰이 만료되면 한 번 재발급하고 원래 요청을 다시 보낸다', () async {
    final tokens = TokenStorage();
    await tokens.save(access: 'old', refresh: 'r1');
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add(
        '${request.method} ${request.url.path} ${request.headers['Authorization'] ?? ''}',
      );
      if (request.url.path == '/api/auth/reissue') {
        expect(jsonDecode(request.body), {'refreshToken': 'r1'});
        return json(200, {
          'accessToken': 'new',
          'refreshToken': 'r2',
          'user': {},
        });
      }
      if (request.headers['Authorization'] == 'Bearer old') {
        return json(401, {'code': 'TOKEN_EXPIRED', 'message': '만료'});
      }
      return json(200, [
        {'ok': true},
      ]);
    });
    final api = ApiClient(
      tokens: tokens,
      client: client,
      baseUrl: 'http://test',
    );

    final result = await api.get('/api/trips');

    expect(result, [
      {'ok': true},
    ]);
    expect(calls, [
      'GET /api/trips Bearer old',
      'POST /api/auth/reissue ',
      'GET /api/trips Bearer new',
    ]);
    expect(tokens.refreshToken, 'r2');
  });

  test('재발급도 실패하면 세션을 지우고 알린다', () async {
    final tokens = TokenStorage();
    await tokens.save(access: 'old', refresh: 'r1');
    var expired = false;
    final api = ApiClient(
      tokens: tokens,
      baseUrl: 'http://test',
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/reissue') {
          return json(401, {'code': 'UNAUTHORIZED', 'message': 'x'});
        }
        return json(401, {'code': 'TOKEN_EXPIRED', 'message': '만료'});
      }),
    )..onSessionExpired = () => expired = true;

    await expectLater(api.get('/api/trips'), throwsA(isA<ApiException>()));
    expect(expired, isTrue);
    expect(tokens.hasSession, isFalse);
  });

  test('서버 오류는 ErrorResponse의 code · message · details로 바꾼다', () async {
    final tokens = TokenStorage();
    final api = ApiClient(
      tokens: tokens,
      baseUrl: 'http://test',
      client: MockClient(
        (request) async => json(409, {
          'status': 409,
          'code': 'SCHEDULE_OVERLAP',
          'message': '다른 일정과 시간이 겹쳐요.',
          'details': {'title': '구로몬 시장', 'startTime': '12:00'},
        }),
      ),
    );

    try {
      await api.post('/api/trips/t/schedules', body: {'title': 'x'});
      fail('예외가 나야 한다');
    } on ApiException catch (e) {
      expect(e.status, 409);
      expect(e.code, 'SCHEDULE_OVERLAP');
      expect(e.details['title'], '구로몬 시장');
      expect(e.displayMessage, '구로몬 시장');
    }
  });

  test('연결이 안 되면 NETWORK 오류다', () async {
    final api = ApiClient(
      tokens: TokenStorage(),
      baseUrl: 'http://test',
      client: MockClient((request) async => throw http.ClientException('down')),
    );

    await expectLater(
      api.get('/api/trips'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isNetworkError,
          'isNetworkError',
          true,
        ),
      ),
    );
  });

  test('null인 쿼리 값은 보내지 않는다', () async {
    Uri? seen;
    final api = ApiClient(
      tokens: TokenStorage(),
      baseUrl: 'http://test',
      client: MockClient((request) async {
        seen = request.url;
        return json(200, {});
      }),
    );

    await api.get('/api/x', query: {'a': 1, 'b': null});

    expect(seen.toString(), 'http://test/api/x?a=1');
  });
}
