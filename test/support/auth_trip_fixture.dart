import 'dart:convert';

import 'package:backpack/core/network/session_tokens.dart';
import 'package:backpack/core/network/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemorySessionStore implements SessionStore {
  SessionTokens? current;
  bool hasSaveError = false;
  @override
  SessionTokens? get tokens => current;
  @override
  Future<void> load() async {}
  @override
  Future<void> save(SessionTokens tokens) async {
    if (hasSaveError) {
      throw StateError('synthetic storage failure');
    }
    current = tokens;
  }

  @override
  Future<void> clear() async {
    current = null;
  }
}

http.Response jsonResponse(int status, Object? data) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Matches main's auth DTOs and feat/trip's TripController DTOs.
class AuthTripFixture {
  bool hasAccount = false;
  bool hasTripError = false;
  String access = 'access-1';
  String refresh = 'refresh-1';
  int signupCalls = 0, loginCalls = 0, refreshCalls = 0, createCalls = 0;
  final List<Map<String, Object?>> trips = [];
  static const String tripId = '019d0d00-0000-7000-8000-000000000010';
  static const String memberId = '019d0d00-0000-7000-8000-000000000020';
  Map<String, Object?>? lastTripRequest;

  Map<String, Object?> detail() => {
    ...trips.first,
    'inviteCode': 'ABCD1234',
    'myMemberId': memberId,
    'createdAt': '2026-10-27T03:00:00Z',
  }..remove('memberCount');

  http.Client client() => MockClient(handle);

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    final body = request.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(request.body) as Map<String, Object?>;
    if (path == '/api/auth/signup') {
      signupCalls++;
      if (hasAccount) {
        return jsonResponse(409, {
          'code': 'CONFLICT',
          'message': '이미 가입되어 있습니다.',
        });
      }
      hasAccount = true;
      return jsonResponse(201, {
        'id': 'user-1',
        'email': body['email'],
        'name': body['name'],
      });
    }
    if (path == '/api/auth/login') {
      loginCalls++;
      if (!hasAccount ||
          body['email'] != 'traveler@example.com' ||
          body['password'] != 'backpack123') {
        return jsonResponse(401, {
          'code': 'UNAUTHORIZED',
          'message': '인증이 필요합니다.',
        });
      }
      return jsonResponse(200, {
        'accessToken': access,
        'refreshToken': refresh,
      });
    }
    if (path == '/api/auth/reissue') {
      refreshCalls++;
      if (body['refreshToken'] != refresh) {
        return jsonResponse(401, {'code': 'UNAUTHORIZED', 'message': '만료된 세션'});
      }
      access = 'access-${refreshCalls + 1}';
      refresh = 'refresh-${refreshCalls + 1}';
      return jsonResponse(200, {
        'accessToken': access,
        'refreshToken': refresh,
      });
    }
    if (path == '/api/auth/logout') {
      return http.Response('', 204);
    }
    if (request.headers['Authorization'] != 'Bearer $access') {
      return jsonResponse(401, {
        'code': 'UNAUTHORIZED',
        'message': '다시 로그인해 주세요.',
      });
    }
    if (path == '/api/trips' && request.method == 'GET') {
      if (hasTripError) {
        return jsonResponse(503, {
          'code': 'INTERNAL_SERVER_ERROR',
          'message': '잠시 후 다시 시도해 주세요.',
        });
      }
      return jsonResponse(200, trips);
    }
    if (path == '/api/trips' && request.method == 'POST') {
      createCalls++;
      lastTripRequest = body;
      trips.add({...body, 'id': tripId, 'memberCount': 1, 'myRole': 'HOST'});
      return jsonResponse(201, detail());
    }
    if (path == '/api/trips/$tripId') {
      return jsonResponse(200, detail());
    }
    if (path == '/api/trips/$tripId/members') {
      return jsonResponse(200, [
        {
          'memberId': memberId,
          'name': '여행자',
          'role': 'HOST',
          'isMe': true,
          'prepaidRate': null,
          'joinedAt': '2026-10-27T03:00:00Z',
        },
      ]);
    }
    return jsonResponse(404, {'code': 'NOT_FOUND', 'message': '찾을 수 없습니다.'});
  }
}
