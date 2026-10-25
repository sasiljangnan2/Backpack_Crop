import 'package:flutter/foundation.dart';

/// 빌드할 때 `--dart-define`으로 넣는 설정.
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://api.backpack.app
/// ```
///
/// 값이 없으면 로컬 개발 서버를 쓴다. 안드로이드 에뮬레이터에서 PC의 localhost는
/// `10.0.2.2`로 보인다.
abstract final class AppConfig {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) {
      return _apiBaseUrl.endsWith('/')
          ? _apiBaseUrl.substring(0, _apiBaseUrl.length - 1)
          : _apiBaseUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  /// Firebase 프로젝트 값. 모두 있을 때만 푸시 알림을 켠다
  /// (없으면 알림함만 쓰고 푸시는 받지 않는다).
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static bool get pushEnabled =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
