import '../../../core/network/json.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.notifySchedule,
    required this.notifyExpense,
    required this.notifySettlement,
  });

  factory AppUser.fromJson(Json json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    notifySchedule: json['notifySchedule'] as bool? ?? true,
    notifyExpense: json['notifyExpense'] as bool? ?? true,
    notifySettlement: json['notifySettlement'] as bool? ?? true,
  );

  final String id;
  final String email;
  final String name;
  final bool notifySchedule;
  final bool notifyExpense;
  final bool notifySettlement;
}

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Json json) => AuthResult(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: AppUser.fromJson(json['user'] as Json),
  );

  final String accessToken;
  final String refreshToken;
  final AppUser user;
}
