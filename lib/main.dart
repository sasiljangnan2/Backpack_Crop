import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'app.dart';
import 'core/theme/app_colors.dart';
import 'features/user/presentation/signup_screen.dart';
import 'features/expense/presentation/expense_split_screen.dart';
import 'home_screen.dart';
export 'app.dart' show MyApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

@Preview(name: 'Backpack 항목별 경비 분담', size: Size(390, 844))
Widget expenseSplitPreview() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(useMaterial3: true, colorScheme: AppColors.scheme),
  home: const ExpenseSplitScreen(),
);
@Preview(name: 'Backpack 여행 홈', size: Size(390, 844))
Widget homePreview() => const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: TravelHomeScreen(),
);
@Preview(name: 'Backpack 회원가입', size: Size(390, 844))
Widget signupPreview() => const MaterialApp(home: SignupScreen());
@Preview(name: 'Backpack 시작 화면', size: Size(390, 844))
Widget welcomePreview() => const MyApp();
