import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';

import 'core/app_dependencies.dart';
import 'core/theme/app_colors.dart';
import 'features/user/presentation/auth_controller.dart';
import 'features/user/presentation/welcome_screen.dart';
import 'features/trip/presentation/trip_list_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.dependencies});
  final AppDependencies? dependencies;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppDependencies _dependencies;
  final _navigator = GlobalKey<NavigatorState>();
  SessionStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ?? AppDependencies.create();
    _dependencies.auth.addListener(_onSessionChanged);
    _dependencies.auth.restore();
  }

  void _onSessionChanged() {
    final auth = _dependencies.auth;
    if (_lastStatus == auth.status) {
      return;
    }
    _lastStatus = auth.status;
    _navigator.currentState?.popUntil((route) => route.isFirst);
    final notice = auth.notice;
    if (auth.status == SessionStatus.signedOut && notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _navigator.currentContext;
        if (mounted && context != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(notice)));
        }
      });
    }
  }

  @override
  void dispose() {
    _dependencies.auth.removeListener(_onSessionChanged);
    if (widget.dependencies == null) {
      _dependencies.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    dependencies: _dependencies,
    child: MaterialApp(
      navigatorKey: _navigator,
      title: 'Backpack',
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        datePickerTheme: const DatePickerThemeData(
          rangePickerHeaderHeadlineStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        colorScheme: AppColors.scheme,
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          errorMaxLines: 3,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: _dependencies.auth,
        builder: (context, child) => switch (_dependencies.auth.status) {
          SessionStatus.restoring => const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.backpack_outlined,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16),
                  Text('Backpack'),
                ],
              ),
            ),
          ),
          SessionStatus.signedOut => const WelcomeScreen(),
          SessionStatus.signedIn => TripListScreen(
            repository: _dependencies.trips,
          ),
        },
      ),
    ),
  );
}
