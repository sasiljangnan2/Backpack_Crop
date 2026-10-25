import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import 'user_models.dart';

class UserApi {
  const UserApi(this._api);

  final ApiClient _api;

  Future<AuthResult> login(String email, String password) async =>
      AuthResult.fromJson(
        await _api.post(
          '/api/auth/login',
          body: {'email': email, 'password': password},
          auth: false,
        ) as Json,
      );

  Future<AuthResult> signup({
    required String email,
    required String password,
    required String name,
  }) async => AuthResult.fromJson(
    await _api.post(
      '/api/auth/signup',
      body: {'email': email, 'password': password, 'name': name},
      auth: false,
    ) as Json,
  );

  Future<void> logout(String refreshToken) =>
      _api.post('/api/auth/logout', body: {'refreshToken': refreshToken});

  Future<AppUser> me() async =>
      AppUser.fromJson(await _api.get('/api/users/me') as Json);

  Future<AppUser> changeName(String name) async => AppUser.fromJson(
    await _api.patch('/api/users/me', body: {'name': name}) as Json,
  );

  Future<AuthResult> changePassword(String current, String next) async =>
      AuthResult.fromJson(
        await _api.patch(
          '/api/users/me/password',
          body: {'currentPassword': current, 'newPassword': next},
        ) as Json,
      );

  Future<AppUser> changeNotificationSettings({
    bool? schedule,
    bool? expense,
    bool? settlement,
  }) async => AppUser.fromJson(
    await _api.patch(
      '/api/users/me/notification-settings',
      body: {
        'notifySchedule': ?schedule,
        'notifyExpense': ?expense,
        'notifySettlement': ?settlement,
      },
    ) as Json,
  );

  Future<void> withdraw(String password) =>
      _api.delete('/api/users/me', body: {'password': password});
}
