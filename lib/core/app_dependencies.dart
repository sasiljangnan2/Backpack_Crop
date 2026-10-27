import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../features/user/data/auth_repository.dart';
import '../features/user/presentation/auth_controller.dart';
import '../features/trip/data/trip_repository.dart';
import 'network/api_client.dart';
import 'network/token_storage.dart';

class AppDependencies {
  AppDependencies._({
    required this.api,
    required this.auth,
    required this.trips,
  });
  factory AppDependencies.create({
    SessionStore? store,
    http.Client? client,
    String? baseUrl,
  }) {
    final storage = store ?? TokenStorage();
    final api = ApiClient(store: storage, client: client, baseUrl: baseUrl);
    final auth = AuthController(
      repository: AuthRepository(api),
      api: api,
      store: storage,
    );
    api.onSessionExpired = auth.expire;
    return AppDependencies._(
      api: api,
      auth: auth,
      trips: ApiTripRepository(api),
    );
  }
  final ApiClient api;
  final AuthController auth;
  final TripRepository trips;
  void dispose() {
    auth.dispose();
    api.close();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.dependencies, required super.child});
  final AppDependencies dependencies;
  static AppDependencies of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.dependencies;
  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
