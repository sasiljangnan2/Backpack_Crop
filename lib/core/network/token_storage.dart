import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 액세스 · 리프레시 토큰 저장소.
///
/// 기기의 보안 저장소(안드로이드 Keystore, iOS Keychain)에 암호화해 둔다.
/// 요청마다 디스크를 읽지 않도록 메모리에도 들고 있는다.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'backpack.accessToken';
  static const _refreshKey = 'backpack.refreshToken';
  static const _sessionKey = 'backpack.session.v1';

  final FlutterSecureStorage _storage;
  String? _access;
  String? _refresh;
  bool _loaded = false;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _refresh != null;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final session = await _storage.read(key: _sessionKey);
      if (session != null) {
        final pair = jsonDecode(session) as Map<String, dynamic>;
        final access = pair['accessToken'] as String;
        final refresh = pair['refreshToken'] as String;
        if (access.isEmpty || refresh.isEmpty) {
          throw const FormatException('Empty session');
        }
        _access = access;
        _refresh = refresh;
      } else {
        // full-app을 먼저 실행했던 기기도 기존 main의 원자적 저장 형식으로 옮긴다.
        final access = await _storage.read(key: _accessKey);
        final refresh = await _storage.read(key: _refreshKey);
        if (access != null && refresh != null) {
          await save(access: access, refresh: refresh);
          await _storage.delete(key: _accessKey);
          await _storage.delete(key: _refreshKey);
        }
      }
    } catch (_) {
      // 앱을 다시 설치해 키가 바뀌면 읽을 수 없다. 다시 로그인하게 한다
      await clear();
    }
    _loaded = true;
  }

  Future<void> save({required String access, required String refresh}) async {
    if (access.isEmpty || refresh.isEmpty) {
      throw const FormatException('Empty session');
    }
    // 두 토큰을 한 항목에 저장해 재발급 중 절반만 갱신되는 일을 막는다.
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode({'accessToken': access, 'refreshToken': refresh}),
    );
    _access = access;
    _refresh = refresh;
    _loaded = true;
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
      await _storage.delete(key: _sessionKey);
    } catch (_) {
      // 지우지 못해도 메모리에서는 이미 지웠다
    }
  }
}
