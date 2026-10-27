import '../../../core/network/api_client.dart';
import '../../../core/network/session_tokens.dart';

class SignupUser {
  const SignupUser({required this.id, required this.email, required this.name});
  final String id;
  final String email;
  final String name;
  factory SignupUser.fromJson(Map<String, Object?> json) => SignupUser(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
  );
  Map<String, Object?> toJson() => {'id': id, 'email': email, 'name': name};
}

class AuthRepository {
  const AuthRepository(this.api);
  final ApiClient api;
  Future<SignupUser> signup({
    required String email,
    required String password,
    required String name,
  }) async => SignupUser.fromJson(
    await api.post(
      '/api/auth/signup',
      hasAuth: false,
      body: {'email': email.trim(), 'password': password, 'name': name.trim()},
    ) as Map<String, Object?>,
  );
  Future<SessionTokens> login(String email, String password) async =>
      SessionTokens.fromJson(
        await api.post(
          '/api/auth/login',
          hasAuth: false,
          body: {'email': email.trim(), 'password': password},
        ) as Map<String, Object?>,
      );
  Future<void> logout(String refreshToken) async {
    await api.post('/api/auth/logout', body: {'refreshToken': refreshToken});
  }
}
