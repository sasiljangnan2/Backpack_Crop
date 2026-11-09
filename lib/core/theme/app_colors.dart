import 'package:flutter/material.dart';

/// 기존 main의 코랄 화면 설계를 모든 서버 연동 화면에 적용한다.
abstract final class AppColors {
  /// 기존 코랄 버튼 · 아이콘 · 선택 테두리 색.
  static const primary = Color(0xFFD0442B);

  /// 강조 글씨도 같은 코랄 색으로 통일한다.
  static const primaryText = primary;
  static const primarySoft = Color(0xFFFFF1EC);
  static const error = Color(0xFFB4235A);

  /// 기존 디자인의 완료 · 예약 확정 · 받을 돈 색.
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
  static const coverText = Color(0xFFFFD9CD);
  // 기존 홈 표지의 버건디 · 코랄 · 살구색 그라데이션.
  static const coverGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5B2333), Color(0xFFDF573C), Color(0xFFF4AD7C)],
    stops: [0, .65, 1],
  );

  /// 밝은 표지 위의 흰 글씨가 묻히지 않게 까는 옅은 그림자
  static const coverShadow = [
    Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 1)),
  ];
  // DAY colors identify itinerary days and are distinct from action colors.
  static const dayTwo = Color(0xFF2D83F5);

  /// 일차별 색 (스토리보드 BC-004 ①). DAY 탭 점 · 번호 핀이 같은 색을 쓴다
  static const _days = [
    Color(0xFFF2711C),
    dayTwo,
    Color(0xFF16A34A),
    Color(0xFF8B5CF6),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFFCA8A04),
  ];

  /// [dayNo]는 1부터
  static Color day(int dayNo) => _days[(dayNo - 1) % _days.length];

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
