import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'features/user/presentation/signup_screen.dart';
import 'features/expense/presentation/expense_split_screen.dart';
import 'home_screen.dart';
export 'app.dart' show MyApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppTypography.registerLicense();
  runApp(const MyApp());
}

@Preview(name: 'Backpack 항목별 경비 분담', size: Size(390, 844))
Widget expenseSplitPreview() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  home: const ExpenseSplitScreen(),
);
@Preview(name: 'Backpack 여행 홈', size: Size(390, 844))
Widget homePreview() => MaterialApp(
  theme: AppTheme.light,
  debugShowCheckedModeBanner: false,
  home: const TravelHomeScreen(),
);
@Preview(name: 'Backpack 회원가입', size: Size(390, 844))
Widget signupPreview() =>
    MaterialApp(theme: AppTheme.light, home: const SignupScreen());
@Preview(name: 'Backpack 시작 화면', size: Size(390, 844))
Widget welcomePreview() => const MyApp();
