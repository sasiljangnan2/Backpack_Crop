import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_services.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/notification/presentation/notification_navigator.dart';
import 'features/trip/presentation/trip_list_screen.dart';

/// 앱 루트. 로그인 상태에 따라 시작 화면과 여행 목록을 바꿔 보여 준다.
class BackpackApp extends StatefulWidget {
  const BackpackApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<BackpackApp> createState() => _BackpackAppState();
}

class _BackpackAppState extends State<BackpackApp> {
  SessionState? _last;
  StreamSubscription<Map<String, dynamic>>? _pushOpened;

  @override
  void initState() {
    super.initState();
    services.auth.addListener(_onAuthChanged);
    _pushOpened = services.push.opened.listen(_openFromPush);
  }

  @override
  void dispose() {
    services.auth.removeListener(_onAuthChanged);
    _pushOpened?.cancel();
    super.dispose();
  }

  // 로그아웃 · 세션 만료 때 쌓여 있던 화면을 모두 닫는다
  void _onAuthChanged() {
    final state = services.auth.state;
    if (_last != state) {
      _last = state;
      BackpackApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  void _openFromPush(Map<String, dynamic> data) {
    final navigator = BackpackApp.navigatorKey.currentState;
    final tripId = data['tripId'] as String?;
    if (navigator == null || tripId == null) {
      return;
    }
    openNotificationTarget(
      navigator,
      tripId: tripId,
      refType: data['refType'] as String?,
      refId: data['refId'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backpack',
      navigatorKey: BackpackApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ListenableBuilder(
        listenable: services.auth,
        builder: (context, _) => switch (services.auth.state) {
          SessionState.loading => const _Splash(),
          SessionState.signedOut => const WelcomeScreen(),
          SessionState.signedIn => const TripListScreen(),
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.backpack_outlined,
            size: 40,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
