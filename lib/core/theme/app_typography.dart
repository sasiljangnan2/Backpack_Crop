import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTypography {
  static const String fontFamily = 'Pretendard';
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
