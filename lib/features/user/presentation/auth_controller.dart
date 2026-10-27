import 'auth_strings.dart';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_storage.dart';
import '../data/auth_repository.dart';

enum SessionStatus { restoring, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController({
    required this.repository,
    required this.api,
    required this.store,
  });
  final AuthRepository repository;
  final ApiClient api;
  final SessionStore store;
  SessionStatus _status = SessionStatus.restoring;
  bool _isDisposed = false;
  String? _notice;
  SessionStatus get status => _status;
  String? get notice => _notice;

  Future<void> restore() async {
    await store.load();
    if (store.tokens == null) {
      _set(SessionStatus.signedOut);
      return;
    }
    try {
      await api.refreshSession();
      _set(
        store.tokens == null ? SessionStatus.signedOut : SessionStatus.signedIn,
      );
    } on ApiException catch (error) {
      if (error.status == 401 || error.status == 403) {
        _set(SessionStatus.signedOut);
      } else {
        _set(SessionStatus.signedIn, notice: AuthStrings.sessionOffline);
      }
    } on Object {
      _set(SessionStatus.signedOut, notice: AuthStrings.restoreFailed);
    }
  }

  Future<void> login(String email, String password) async {
    final tokens = await repository.login(email, password);
    await store.save(tokens);
    _set(SessionStatus.signedIn);
  }

  Future<void> logout() async {
    if (store.tokens != null) {
      try {
        // Rotate before logout so the request revokes the current refresh token.
        await api.refreshSession();
        final refresh = store.tokens?.refreshToken;
        if (refresh != null) {
          await repository.logout(refresh);
        }
      } on ApiException {
        // The device can still end its session when the server is unreachable.
      }
    }
    await store.clear();
    _set(SessionStatus.signedOut);
  }

  void expire() =>
      _set(SessionStatus.signedOut, notice: AuthStrings.sessionExpired);

  void _set(SessionStatus status, {String? notice}) {
    if (_isDisposed) {
      return;
    }
    _status = status;
    _notice = notice;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
