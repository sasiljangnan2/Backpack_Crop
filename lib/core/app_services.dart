import 'package:flutter/foundation.dart';

import '../features/expense/data/expense_api.dart';
import '../features/notification/data/notification_api.dart';
import '../features/schedule/data/schedule_api.dart';
import '../features/task/data/task_api.dart';
import '../features/trip/data/trip_api.dart';
import '../features/user/data/user_api.dart';
import '../features/user/data/user_models.dart';
import 'network/api_client.dart';
import 'network/api_exception.dart';
import 'network/token_storage.dart';
import 'push/push_service.dart';

enum SessionState { loading, signedOut, signedIn }

/// 로그인 상태. 앱 전체가 이것을 보고 시작 화면과 여행 목록 중 어디를 보여 줄지 정한다.
class AuthController extends ChangeNotifier {
  AuthController(this._tokens, this._users, this._push);

  final TokenStorage _tokens;
  final UserApi _users;
  final PushService _push;

  SessionState _state = SessionState.loading;
  AppUser? _user;

  SessionState get state => _state;
  AppUser? get user => _user;

  /// 앱을 켤 때: 저장된 토큰이 있으면 내 정보를 불러 로그인 상태로 둔다.
  Future<void> restore() async {
    await _tokens.load();
    if (!_tokens.hasSession) {
      _set(SessionState.signedOut, null);
      return;
    }
    try {
      _set(SessionState.signedIn, await _users.me());
      _push.register();
    } on ApiException catch (e) {
      // 오프라인이면 다시 로그인하라고 하지 않는다. 다음 요청 때 다시 확인한다
      if (e.isNetworkError) {
        _set(SessionState.signedIn, null);
      } else {
        await _tokens.clear();
        _set(SessionState.signedOut, null);
      }
    }
  }

  Future<void> login(String email, String password) async {
    final result = await _users.login(email.trim(), password);
    await _start(result);
  }

  Future<void> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    final result = await _users.signup(
      email: email.trim(),
      password: password,
      name: name.trim(),
    );
    await _start(result);
  }

  Future<void> applyTokens(AuthResult result) async {
    await _tokens.save(
      access: result.accessToken,
      refresh: result.refreshToken,
    );
    _set(SessionState.signedIn, result.user);
  }

  void updateUser(AppUser user) => _set(_state, user);

  Future<AppUser?> refreshUser() async {
    try {
      final user = await _users.me();
      _set(SessionState.signedIn, user);
      return user;
    } on ApiException {
      return _user;
    }
  }

  Future<void> logout() async {
    final refresh = _tokens.refreshToken;
    await _push.unregister();
    if (refresh != null) {
      try {
        await _users.logout(refresh);
      } on ApiException {
        // 서버에 알리지 못해도 기기에서는 로그아웃한다
      }
    }
    await _tokens.clear();
    _set(SessionState.signedOut, null);
  }

  /// 탈퇴 · 세션 만료처럼 서버 쪽 세션이 이미 끝났을 때
  Future<void> forceSignOut() async {
    await _tokens.clear();
    _set(SessionState.signedOut, null);
  }

  Future<void> _start(AuthResult result) async {
    await applyTokens(result);
    _push.register();
  }

  void _set(SessionState state, AppUser? user) {
    _state = state;
    _user = user;
    notifyListeners();
  }
}

/// 앱 전체에서 쓰는 서비스 모음. main()에서 한 번 만든다.
class AppServices {
  AppServices._(this.tokens, this.api) {
    users = UserApi(api);
    trips = TripApi(api);
    schedules = ScheduleApi(api);
    expenses = ExpenseApi(api);
    tasks = TaskApi(api);
    notifications = NotificationApi(api);
    push = PushService(notifications);
    auth = AuthController(tokens, users, push);
    api.onSessionExpired = auth.forceSignOut;
  }

  factory AppServices.create() {
    final tokens = TokenStorage();
    return AppServices._(tokens, ApiClient(tokens: tokens));
  }

  /// 테스트용: 가짜 HTTP 클라이언트를 붙인 [ApiClient]를 받는다.
  @visibleForTesting
  factory AppServices.withClient(ApiClient api) =>
      AppServices._(api.tokens, api);

  final TokenStorage tokens;
  final ApiClient api;
  late final UserApi users;
  late final TripApi trips;
  late final ScheduleApi schedules;
  late final ExpenseApi expenses;
  late final TaskApi tasks;
  late final NotificationApi notifications;
  late final PushService push;
  late final AuthController auth;
}

/// main()에서 채운다. 화면은 `services.trips` 처럼 쓴다.
late final AppServices services;
