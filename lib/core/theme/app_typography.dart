import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const String fontFamily = 'Pretendard';
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    color: AppColors.ink,
  );
  static const TextStyle money = TextStyle(
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static bool _hasRegisteredLicense = false;

  static void registerLicense() {
    if (_hasRegisteredLicense) {
      return;
    }
    _hasRegisteredLicense = true;
    LicenseRegistry.addLicense(() async* {
      final license = await rootBundle.loadString('assets/fonts/OFL.txt');
      yield LicenseEntryWithLineBreaks(['Pretendard'], license);
    });
  }
}
