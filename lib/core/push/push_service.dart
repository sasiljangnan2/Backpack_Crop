import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/notification/data/notification_api.dart';
import '../config/app_config.dart';

/// FCM 푸시. Firebase 값(`--dart-define=FIREBASE_*`)이 있을 때만 켜진다.
///
/// 값이 없으면 아무 일도 하지 않는다. 그래도 알림함(서버 저장)은 그대로 동작한다.
/// 알림을 눌러 앱이 열리면 [opened]로 알림 데이터(tripId, refType, refId)를 보낸다.
class PushService {
  PushService(this._api);

  final NotificationApi _api;
  final _opened = StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;
  String? _token;

  Stream<Map<String, dynamic>> get opened => _opened.stream;

  /// 포그라운드에서 받은 알림 수를 앱 배지에 반영하라는 신호
  final ValueNotifier<int> received = ValueNotifier(0);

  Future<void> initialize() async {
    if (!AppConfig.pushEnabled || _initialized) {
      return;
    }
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseSenderId,
          projectId: AppConfig.firebaseProjectId,
        ),
      );
      _initialized = true;
      FirebaseMessaging.onMessage.listen((_) => received.value++);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _opened.add(message.data),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _opened.add(initial.data);
      }
      // 서버(Firebase Admin SDK)는 FCM 등록 토큰으로 보낸다. 새 register()/onRegistered는
      // 설치 ID(FID)를 주므로 서버가 FID 발송을 지원할 때 함께 바꾼다
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen(_send);
    } catch (e) {
      debugPrint('푸시를 켜지 못했습니다: $e');
    }
  }

  /// 로그인 뒤 부른다: 권한을 묻고 기기 토큰을 서버에 등록한다.
  Future<void> register() async {
    if (!_initialized) {
      return;
    }
    try {
      await FirebaseMessaging.instance.requestPermission();
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _send(token);
      }
    } catch (e) {
      debugPrint('푸시 토큰을 등록하지 못했습니다: $e');
    }
  }

  /// 로그아웃 전에 부른다: 이 기기로 더 이상 푸시를 보내지 않게 한다.
  Future<void> unregister() async {
    final token = _token;
    if (!_initialized || token == null) {
      return;
    }
    try {
      await _api.removeDevice(token);
    } catch (_) {
      // 로그아웃은 계속 진행한다
    }
    _token = null;
  }

  Future<void> _send(String token) async {
    _token = token;
    try {
      await _api.registerDevice(token);
    } catch (e) {
      debugPrint('푸시 토큰을 서버에 보내지 못했습니다: $e');
    }
  }
}
