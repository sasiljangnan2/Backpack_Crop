import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../schedule_strings.dart';
import '../../data/schedule_models.dart';

class ScheduleDayStrip extends StatefulWidget {
  const ScheduleDayStrip({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.selectedDay,
    required this.onSelected,
  });
  final String startDate, endDate, selectedDay;
  final ValueChanged<String> onSelected;
  @override
  State<ScheduleDayStrip> createState() => _ScheduleDayStripState();
}

class _ScheduleDayStripState extends State<ScheduleDayStrip> {
  late final ScrollController _scroll = ScrollController();
  @override
  void didUpdateWidget(ScheduleDayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) {
      _reveal();
    }
  }

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !_scroll.hasClients) {
      return;
    }
    final index = scheduleDate(widget.selectedDay)
        .difference(scheduleDate(widget.startDate))
        .inDays;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final width = math.max(80.0, 82 * scale);
    _scroll.animateTo(
      (index * (width + 8)).clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  });
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = scheduleDate(widget.startDate);
    final count = scheduleDate(widget.endDate).difference(start).inDays + 1;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final width = math.max(80.0, 82 * scale);
    return SizedBox(
      height: math.max(84, 72 * scale),
      child: ListView.separated(
        key: const ValueKey('schedule-day-strip'),
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: count,
        itemBuilder: (context, index) {
          final day = scheduleDateString(start.add(Duration(days: index)));
          final selected = day == widget.selectedDay;
          return Semantics(
            excludeSemantics: true,
            onTap: () => widget.onSelected(day),
            selected: selected,
            button: true,
            label: ScheduleStrings.dateSemantics(day, index),
            child: SizedBox(
              width: width,
              child: OutlinedButton(
                key: ValueKey('schedule-day-$day'),
                onPressed: () => widget.onSelected(day),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  backgroundColor: selected ? AppColors.primary : Colors.white,
                  foregroundColor: selected ? Colors.white : AppColors.ink,
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ScheduleStrings.dayLabel(index),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ScheduleStrings.shortDate(day),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
      ),
    );
  }
}
