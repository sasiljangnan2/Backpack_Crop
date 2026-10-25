import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// 서버 API 호출의 공통 처리.
///
/// - JSON 요청·응답, `Authorization: Bearer` 헤더
/// - 액세스 토큰이 만료되면(`TOKEN_EXPIRED`) 리프레시 토큰으로 한 번만 재발급하고 다시 보낸다.
///   동시에 여러 요청이 만료돼도 재발급은 한 번만 한다.
/// - 재발급도 실패하면 [onSessionExpired]를 불러 로그인 화면으로 보낸다.
class ApiClient {
  ApiClient({required this.tokens, http.Client? client, String? baseUrl})
    : _http = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  static const _timeout = Duration(seconds: 15);

  final TokenStorage tokens;
  final http.Client _http;
  final String _baseUrl;
  Future<bool>? _refreshing;

  /// 세션이 끊겼을 때(재발급 실패, 탈퇴 등) 한 번 불린다.
  VoidCallback? onSessionExpired;

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool auth = true,
    bool retry = true,
  }) async {
    final response = await _raw(method, path, query, body, auth);
    if (response.statusCode == 401 && auth) {
      final error = _parseError(response);
      if (error.code == 'TOKEN_EXPIRED' && retry && await _refresh()) {
        return _send(method, path, query: query, body: body, retry: false);
      }
      if (tokens.hasSession) {
        await tokens.clear();
        onSessionExpired?.call();
      }
      throw error;
    }
    if (response.statusCode >= 400) {
      throw _parseError(response);
    }
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<http.Response> _raw(
    String method,
    String path,
    Map<String, Object?>? query,
    Object? body,
    bool auth,
  ) async {
    final params = <String, String>{
      for (final entry in (query ?? const {}).entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: params.isEmpty ? null : params);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    final access = tokens.accessToken;
    if (auth && access != null) {
      request.headers['Authorization'] = 'Bearer $access';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      return await http.Response.fromStream(streamed).timeout(_timeout);
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

  Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = tokens.refreshToken;
    if (refresh == null) {
      return false;
    }
    try {
      final response = await _raw('POST', '/api/auth/reissue', null, {
        'refreshToken': refresh,
      }, false);
      if (response.statusCode != 200) {
        return false;
      }
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      await tokens.save(
        access: json['accessToken'] as String,
        refresh: json['refreshToken'] as String,
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  ApiException _parseError(http.Response response) {
    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final details = <String, String>{
        for (final entry
            in ((json['details'] as Map<String, dynamic>?) ?? const {}).entries)
          entry.key: entry.value.toString(),
      };
      return ApiException(
        status: response.statusCode,
        code: json['code'] as String? ?? 'UNKNOWN',
        message: json['message'] as String? ?? '요청을 처리하지 못했어요.',
        details: details,
      );
    } catch (_) {
      return ApiException(
        status: response.statusCode,
        code: 'UNKNOWN',
        message: response.statusCode >= 500
            ? '서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.'
            : '요청을 처리하지 못했어요.',
      );
    }
  }
}
