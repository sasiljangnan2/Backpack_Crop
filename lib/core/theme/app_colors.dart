import 'package:flutter/material.dart';

/// StoryBoardUI설계서 Backpack v1.1, BC-001 (slide 5). 주요 색은 코랄.
abstract final class AppColors {
  /// 코랄. 버튼 · 아이콘 · 테두리 · 막대처럼 면이나 선에 쓴다 (흰 글씨 3.3:1)
  static const primary = Color(0xFFEE5E52);

  /// 진한 코랄. 흰 바탕이나 [primarySoft] 위의 작은 글씨에 쓴다 (흰 바탕 5.5:1)
  static const primaryText = Color(0xFFBA3E33);
  static const primarySoft = Color(0xFFFFF2EF);
  static const error = Color(0xFFB4235A);
  static const success = Color(0xFF0B7A55);
  static const warning = Color(0xFFA35F00);
  static const ink = Color(0xFF191F28);
  static const muted = Color(0xFF4E5968);
  static const background = Color(0xFFF2F4F6);
  static const card = Colors.white;
  static const border = Color(0xFFD0D5DB);
  static const disabled = Color(0xFFD2D7DC);
  static const successSoft = Color(0xFFEAF6F1);
  static const warningSoft = Color(0xFFFFF4E2);
  static const coverText = Color(0xFFFFE3DC);
  // 여행 표지: 위는 어둡게 해서 흰 글씨를 읽기 쉽게 하고, 아래(도시 실루엣)로 갈수록 밝은 코랄
  static const coverGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5A2430), Color(0xFFE4574B), Color(0xFFFFB09C)],
    stops: [0, .68, 1],
  );
  // DAY colors identify itinerary days and are distinct from action colors.
  static const dayTwo = Color(0xFF2D83F5);

  static ColorScheme get scheme => ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: primarySoft,
    onPrimaryContainer: primaryText,
    secondary: primary,
    onSecondary: Colors.white,
    secondaryContainer: primarySoft,
    onSecondaryContainer: primaryText,
    error: error,
    onError: Colors.white,
    surface: card,
    onSurface: ink,
    onSurfaceVariant: muted,
    outline: border,
  );
}
