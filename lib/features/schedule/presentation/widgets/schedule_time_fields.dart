import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../schedule_strings.dart';

class ScheduleTimeFields extends StatelessWidget {
  const ScheduleTimeFields({
    super.key,
    required this.start,
    required this.end,
    required this.onStart,
    required this.onEnd,
  });
  final String start, end;
  final VoidCallback onStart, onEnd;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final children = [
        _TimeButton(
          label: ScheduleStrings.start,
          time: start,
          onPressed: onStart,
          buttonKey: 'schedule-start',
        ),
        _TimeButton(
          label: ScheduleStrings.end,
          time: end,
          onPressed: onEnd,
          buttonKey: 'schedule-end',
        ),
      ];
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(16) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [children[0], const SizedBox(height: 12), children[1]],
        );
      }
      return Row(
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 12),
          Expanded(child: children[1]),
        ],
      );
    },
  );
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onPressed,
    required this.buttonKey,
  });
  final String label, time, buttonKey;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: ValueKey(buttonKey),
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 80),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 5),
        Text(
          time,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ],
    ),
  );
}
