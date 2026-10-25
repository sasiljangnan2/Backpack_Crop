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
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
    } catch (_) {
      // 앱을 다시 설치해 키가 바뀌면 읽을 수 없다. 다시 로그인하게 한다
      await clear();
    }
    _loaded = true;
  }

  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {
      // 지우지 못해도 메모리에서는 이미 지웠다
    }
  }
}
