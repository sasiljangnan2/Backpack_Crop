import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 외국어 이름 밑에 붙이는 한국어 번역 한 줄 (영수증에서 읽은 가게 · 항목 이름)
class Translation extends StatelessWidget {
  const Translation(
    this.text, {
    super.key,
    this.indent = 0,
    this.fontSize = 12,
  });

  final String text;
  final double indent;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 2, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: AppColors.muted,
          height: 1.3,
        ),
      ),
    );
  }
}
