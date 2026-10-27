import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/schedule_models.dart';
import '../schedule_strings.dart';

enum ScheduleAction { edit, lock, unlock, delete }

class ScheduleDetailsSheet extends StatelessWidget {
  const ScheduleDetailsSheet({
    super.key,
    required this.record,
    required this.canEdit,
  });
  final ScheduleRecord record;
  final bool canEdit;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            record.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            '${ScheduleStrings.dateLabel(record.day)} · ${ScheduleStrings.timeRange(record)}',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (record.draft.placeText?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(record.draft.placeText!),
          ],
          const SizedBox(height: 16),
          Text(
            ScheduleStrings.reservationLabel(record.draft.reservationStatus),
          ),
          const SizedBox(height: 16),
          Text(
            record.draft.memo?.isNotEmpty == true
                ? record.draft.memo!
                : ScheduleStrings.noMemo,
            style: const TextStyle(color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 20),
          Text(
            '${ScheduleStrings.author} · ${record.createdBy.name}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (record.isLocked) ...[
            const SizedBox(height: 20),
            const Text(
              ScheduleStrings.lockedHint,
              style: TextStyle(color: AppColors.muted, height: 1.6),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: record.isLocked
                  ? null
                  : () => Navigator.pop(context, ScheduleAction.edit),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text(ScheduleStrings.edit),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(
                context,
                record.isLocked ? ScheduleAction.unlock : ScheduleAction.lock,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: Icon(
                record.isLocked ? Icons.lock_open_outlined : Icons.lock_outline,
              ),
              label: Text(
                record.isLocked ? ScheduleStrings.unlock : ScheduleStrings.lock,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: record.isLocked
                  ? null
                  : () => Navigator.pop(context, ScheduleAction.delete),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text(ScheduleStrings.delete),
            ),
          ] else ...[
            const SizedBox(height: 20),
            const Text(
              ScheduleStrings.readOnly,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    ),
  );
}
