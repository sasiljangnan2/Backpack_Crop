import 'package:flutter/material.dart';

/// StoryBoardUI설계서 Backpack v1.1, BC-001 (slide 5). 주요 색은 에메랄드.
abstract final class AppColors {
  /// 에메랄드. 버튼 · 아이콘 · 테두리 · 막대처럼 면이나 선에 쓴다 (흰 글씨 3.5:1)
  static const primary = Color(0xFF009B77);

  /// 진한 에메랄드. 흰 바탕이나 [primarySoft] 위의 작은 글씨에 쓴다 (흰 바탕 5.6:1)
  static const primaryText = Color(0xFF04765A);
  static const primarySoft = Color(0xFFE8F7F1);
  static const error = Color(0xFFB4235A);

  /// 완료 · 예약 확정 · 받을 돈. 주요 색이 초록 계열이라 링크처럼 보이지 않게 파랑으로 둔다
  static const success = Color(0xFF1D64D8);
  static const warning = Color(0xFFA35F00);
  static const ink = Color(0xFF191F28);
  static const muted = Color(0xFF4E5968);
  static const background = Color(0xFFF2F4F6);
  static const card = Colors.white;
  static const border = Color(0xFFD0D5DB);
  static const disabled = Color(0xFFD2D7DC);
  static const successSoft = Color(0xFFEAF1FD);
  static const warningSoft = Color(0xFFFFF4E2);
  static const coverText = Color(0xFFF0FFF9);
  // 여행 표지: 진한 에메랄드에서 아래(도시 실루엣)로 갈수록 밝은 민트
  static const coverGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF00805F), Color(0xFF00A67E), Color(0xFF8EE2C4)],
    stops: [0, .6, 1],
  );

  /// 밝은 표지 위의 흰 글씨가 묻히지 않게 까는 옅은 그림자
  static const coverShadow = [
    Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 1)),
  ];
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
