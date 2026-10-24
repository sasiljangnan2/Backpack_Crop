import 'package:flutter/material.dart';

/// StoryBoardUI설계서 Backpack v1.1, BC-001 (slide 5).
abstract final class AppColors {
  static const primary = Color(0xFFD0442B);
  static const primarySoft = Color(0xFFFFF1EC);
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
  static const coverText = Color(0xFFFFD9CD);
  // Sampled from the coral travel cover embedded in the reference deck.
  static const coverGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5B2333), Color(0xFFDF573C), Color(0xFFF4AD7C)],
    stops: [0, .65, 1],
  );
  // DAY colors identify itinerary days and are distinct from action colors.
  static const dayTwo = Color(0xFF2D83F5);

  static ColorScheme get scheme => ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: primarySoft,
    onPrimaryContainer: primary,
    secondary: primary,
    onSecondary: Colors.white,
    secondaryContainer: primarySoft,
    onSecondaryContainer: primary,
    error: error,
    onError: Colors.white,
    surface: card,
    onSurface: ink,
    onSurfaceVariant: muted,
    outline: border,
  );
}
