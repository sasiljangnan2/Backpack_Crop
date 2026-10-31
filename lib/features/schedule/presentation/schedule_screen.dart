import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../trip/data/trip_repository.dart';
import '../data/schedule_models.dart';
import '../data/schedule_repository.dart';
import 'schedule_controller.dart';
import 'schedule_form_screen.dart';
import 'schedule_strings.dart';
import 'widgets/schedule_card.dart';
import 'widgets/schedule_day_strip.dart';
import 'widgets/schedule_details_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.trip,
    required this.repository,
    this.isPreview = false,
    this.isEmbedded = false,
  });
  final TripDetail trip;
  final ScheduleRepository repository;
  final bool isPreview;
  final bool isEmbedded;
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final ScheduleController _controller;
  @override
  void initState() {
    super.initState();
    _controller = ScheduleController(
      repository: widget.repository,
      trip: widget.trip,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit({ScheduleRecord? current}) async {
    if (!_controller.canEdit ||
        _controller.isMutating ||
        current?.isLocked == true) {
      return;
    }
    final saved = await Navigator.push<ScheduleRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleFormScreen(
          trip: widget.trip,
          day: _controller.day,
          current: current,
          existingSchedules: _controller.all,
          onSave: (draft, latest) => _controller.save(draft, current: latest),
          onLoadLatest: (id) async {
            await _controller.load();
            if (_controller.error != null) {
              throw StateError('Could not load latest schedules');
            }
            for (final record in _controller.all) {
              if (record.id == id) {
                return record;
              }
            }
            return null;
          },
        ),
      ),
    );
    if (saved != null && mounted) {
      _message(
        current == null ? ScheduleStrings.saved : ScheduleStrings.updated,
      );
    }
  }

  Future<void> _details(ScheduleRecord record) async {
    if (_controller.isMutating) {
      return;
    }
    final action = await showModalBottomSheet<ScheduleAction>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) =>
          ScheduleDetailsSheet(record: record, canEdit: _controller.canEdit),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == ScheduleAction.edit) {
      await _edit(current: record);
      return;
    }
    if (action == ScheduleAction.delete) {
      final delete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(ScheduleStrings.deleteTitle),
          content: Text(
            '${record.title}\n${ScheduleStrings.dateLabel(record.day)} · ${ScheduleStrings.timeRange(record)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(ScheduleStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text(ScheduleStrings.delete),
            ),
          ],
        ),
      );
      if (!mounted || delete != true) {
        return;
      }
    }
    try {
      if (action == ScheduleAction.delete) {
        await _controller.remove(record);
        _message(ScheduleStrings.deleted);
      } else {
        final isLocked = action == ScheduleAction.lock;
        await _controller.lock(record, isLocked: isLocked);
        _message(
          isLocked ? ScheduleStrings.lockDone : ScheduleStrings.unlockDone,
        );
      }
    } on ApiException catch (error) {
      _message(error.displayMessage);
      if (error.code == 'CONFLICT') {
        _controller.load();
      }
    } on Object {
      _message(ScheduleStrings.saveError);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, child) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isEmbedded,
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              ScheduleStrings.title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              widget.trip.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScheduleDayStrip(
            startDate: widget.trip.startDate,
            endDate: widget.trip.endDate,
            selectedDay: _controller.day,
            onSelected: _controller.selectDay,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ScheduleStrings.dateLabel(_controller.day),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      ScheduleStrings.summary(
                        _controller.items.length,
                        _controller.durationMinutes,
                      ),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    if (_controller.lockedCount > 0)
                      Text(
                        '${ScheduleStrings.locked} ${_controller.lockedCount}',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                if (widget.isPreview) ...[
                  const SizedBox(height: 10),
                  const Text(
                    ScheduleStrings.preview,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
                if (!_controller.canEdit) ...[
                  const SizedBox(height: 10),
                  const Text(
                    ScheduleStrings.readOnly,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (_controller.isLoading || _controller.isMutating)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _controller.load,
              child: ListView(
                key: const ValueKey('schedule-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (_controller.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Text(
                            _controller.error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                          TextButton(
                            onPressed: _controller.load,
                            child: const Text(ScheduleStrings.retry),
                          ),
                        ],
                      ),
                    ),
                  if (!_controller.isLoading &&
                      _controller.error == null &&
                      _controller.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_note_outlined,
                            size: 56,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 18),
                          Text(
                            ScheduleStrings.empty,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            ScheduleStrings.emptyHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  for (final record in _controller.items)
                    ScheduleCard(
                      key: ValueKey('schedule-${record.id}'),
                      record: record,
                      onTap: () => _details(record),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: !_controller.canEdit
          ? null
          : SafeArea(
              top: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: FilledButton.icon(
                  key: const ValueKey('schedule-add'),
                  onPressed: _controller.isMutating || _controller.isLoading
                      ? null
                      : () => _edit(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(ScheduleStrings.add),
                ),
              ),
            ),
    ),
  );
}
