import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/schedule_models.dart';
import '../schedule_strings.dart';

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({super.key, required this.record, required this.onTap});
  final ScheduleRecord record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = record.draft.reservationStatus;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ScheduleStrings.timeRange(record),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                record.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (record.draft.placeText?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        record.draft.placeText!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (record.isLocked || status != ReservationStatus.none) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (record.isLocked)
                      const _StatusPill(
                        label: ScheduleStrings.locked,
                        icon: Icons.lock_outline,
                        color: AppColors.ink,
                        background: AppColors.background,
                      ),
                    if (status != ReservationStatus.none)
                      _StatusPill(
                        label: ScheduleStrings.reservationLabel(status),
                        icon: status == ReservationStatus.confirmed
                            ? Icons.check_circle_outline
                            : Icons.hourglass_top,
                        color: status == ReservationStatus.confirmed
                            ? AppColors.success
                            : AppColors.warning,
                        background: status == ReservationStatus.confirmed
                            ? AppColors.successSoft
                            : AppColors.warningSoft,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });
  final String label;
  final IconData icon;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
