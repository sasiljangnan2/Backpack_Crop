import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';
import 'session_tokens.dart';
import 'token_storage.dart';

/// JSON, ErrorResponse and single-flight token rotation shared by all features.
class ApiClient {
  ApiClient({required this.store, http.Client? client, String? baseUrl})
    : _http = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;
  final SessionStore store;
  final http.Client _http;
  final String _baseUrl;
  Future<void>? _refreshing;
  VoidCallback? onSessionExpired;

  Future<Object?> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);
  Future<void> delete(String path) async {
    await _send('DELETE', path);
  }

  Future<Object?> get(String path) => _send('GET', path);
  Future<Object?> post(String path, {Object? body, bool hasAuth = true}) =>
      _send('POST', path, body: body, hasAuth: hasAuth);

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    bool hasAuth = true,
    bool canRetry = true,
  }) async {
    final requestedAccess = store.tokens?.accessToken;
    final response = await _raw(method, path, body, hasAuth: hasAuth);
    if (response.statusCode == 401 && hasAuth) {
      if (store.tokens?.accessToken != requestedAccess &&
          canRetry &&
          store.tokens != null) {
        return _send(
          method,
          path,
          body: body,
          hasAuth: hasAuth,
          canRetry: false,
        );
      }
      final error = _error(response);
      if (error.code == 'TOKEN_EXPIRED' && canRetry) {
        // Network failures retain the session and are presented as retryable.
        await refreshSession();
        return _send(
          method,
          path,
          body: body,
          hasAuth: hasAuth,
          canRetry: false,
        );
      }
      await store.clear();
      onSessionExpired?.call();
      throw error;
    }
    return _decode(response);
  }

  Future<void> refreshSession() =>
      _refreshing ??= _rotate().whenComplete(() => _refreshing = null);

  Future<void> _rotate() async {
    final refresh = store.tokens?.refreshToken;
    if (refresh == null) {
      throw const ApiException(
        status: 401,
        code: 'UNAUTHORIZED',
        message: '다시 로그인해 주세요.',
      );
    }
    final response = await _raw('POST', '/api/auth/reissue', {
      'refreshToken': refresh,
    }, hasAuth: false);
    if (store.tokens?.refreshToken != refresh) {
      return;
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      await store.clear();
      onSessionExpired?.call();
    }
    final json = _decode(response) as Map<String, Object?>;
    await store.save(SessionTokens.fromJson(json));
  }

  Future<http.Response> _raw(
    String method,
    String path,
    Object? body, {
    required bool hasAuth,
  }) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers['Accept'] = 'application/json';
    final tokens = store.tokens;
    if (hasAuth && tokens != null) {
      request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    try {
      final stream = await _http
          .send(request)
          .timeout(const Duration(seconds: 15));
      return await http.Response.fromStream(stream)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException.timeout();
    } on SocketException {
      throw const ApiException.network();
    } on http.ClientException {
      throw const ApiException.network();
    } on HandshakeException {
      throw const ApiException.network();
    }
  }

  Object? _decode(http.Response response) {
    if (response.statusCode >= 400) {
      throw _error(response);
    }
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException(
        status: 502,
        code: 'INVALID_RESPONSE',
        message: '서버 응답을 읽지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  ApiException _error(http.Response response) {
    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
      final details = json['details'] as Map<String, Object?>? ?? const {};
      return ApiException(
        status: response.statusCode,
        code: json['code'] as String? ?? 'UNKNOWN',
        message: json['message'] as String? ?? '요청을 처리하지 못했어요.',
        details: details.map((key, value) => MapEntry(key, value.toString())),
      );
    } on Object {
      return ApiException(
        status: response.statusCode,
        code: 'UNKNOWN',
        message: response.statusCode >= 500
            ? '서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.'
            : '요청을 처리하지 못했어요.',
      );
    }
  }

  void close() => _http.close();
}
