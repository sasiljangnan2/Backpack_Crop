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
          // 서버가 실제로 보내는 순서 (ScheduleService: scheduleId가 맨 앞)
          'details': {
            'scheduleId': '01a1c40d-f865-712a-bd80-d3ce7c086aa0',
            'title': '구로몬 시장',
            'day': '2026-10-03',
            'startTime': '12:00',
            'endTime': '13:00',
            'overlapCount': 1,
          },
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
      expect(e.details['overlapCount'], '1');
      // details의 첫 값(일정 id)이 아니라 겹친 일정을 알려 주는 문장
      expect(
        e.displayMessage,
        "그 시간에 '구로몬 시장' (12:00–13:00) 일정이 있어요. 시간을 바꾸거나 그 일정을 먼저 옮겨 주세요.",
      );
    }
  });

  test('필드 메시지가 있으면 그것을, 없으면 전체 메시지를 보여 준다', () {
    const field = ApiException(
      status: 400,
      code: 'INVALID_INPUT',
      message: '입력값이 올바르지 않습니다.',
      details: {'email': '이메일 형식이 올바르지 않아요.'},
    );
    const plain = ApiException(
      status: 404,
      code: 'NOT_FOUND',
      message: '요청한 리소스를 찾을 수 없습니다.',
    );
    const overlapWithoutTitle = ApiException(
      status: 409,
      code: 'SCHEDULE_OVERLAP',
      message: '다른 일정과 시간이 겹쳐요.',
      details: {'scheduleId': 'x'},
    );

    expect(field.displayMessage, '이메일 형식이 올바르지 않아요.');
    expect(plain.displayMessage, '요청한 리소스를 찾을 수 없습니다.');
    expect(overlapWithoutTitle.displayMessage, '다른 일정과 시간이 겹쳐요.');
  });

  test('details에 값(id · 버전 · 개수)을 담는 오류는 그 값이 아니라 메시지를 보여 준다', () {
    // 서버가 실제로 보내는 형태 (ScheduleService · TripService)
    const locked = ApiException(
      status: 409,
      code: 'SCHEDULE_LOCKED',
      message: '고정된 일정이에요. 고정을 먼저 풀어 주세요.',
      details: {'scheduleId': '01a1c40d-f865-712a-bd80-d3ce7c086aa0'},
    );
    const version = ApiException(
      status: 409,
      code: 'VERSION_CONFLICT',
      message: '다른 사람이 먼저 수정했어요. 새로고침 후 다시 시도해 주세요.',
      details: {'version': '3'},
    );

    expect(locked.displayMessage, '고정된 일정이에요. 고정을 먼저 풀어 주세요.');
    expect(version.displayMessage, '다른 사람이 먼저 수정했어요. 새로고침 후 다시 시도해 주세요.');
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
