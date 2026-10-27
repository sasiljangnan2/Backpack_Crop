import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_tokens.dart';

abstract interface class SessionStore {
  SessionTokens? get tokens;
  Future<void> load();
  Future<void> save(SessionTokens tokens);
  Future<void> clear();
}

/// Both tokens use one encrypted entry so a rotation cannot save half a pair.
class TokenStorage implements SessionStore {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  static const String _key = 'backpack.session.v1';
  final FlutterSecureStorage _storage;
  SessionTokens? _tokens;
  bool _isLoaded = false;

  @override
  SessionTokens? get tokens => _tokens;

  @override
  Future<void> load() async {
    if (_isLoaded) {
      return;
    }
    try {
      final value = await _storage.read(key: _key);
      if (value != null) {
        _tokens = SessionTokens.fromJson(
          jsonDecode(value) as Map<String, Object?>,
        );
      }
    } on Object {
      _tokens = null;
    }
    _isLoaded = true;
  }

  @override
  Future<void> save(SessionTokens tokens) async {
    await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
    _tokens = tokens;
    _isLoaded = true;
  }

  @override
  Future<void> clear() async {
    // Keep the current state if the device refuses to remove the saved session.
    await _storage.delete(key: _key);
    _tokens = null;
  }
}
