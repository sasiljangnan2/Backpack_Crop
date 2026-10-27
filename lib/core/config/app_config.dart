import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const String _configured = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_configured.isNotEmpty) {
      return _configured.replaceFirst(RegExp(r'/+$'), '');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
