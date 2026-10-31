import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../trip/data/trip_repository.dart';
import '../data/schedule_models.dart';
import 'schedule_strings.dart';
import 'widgets/schedule_time_fields.dart';

class ScheduleFormScreen extends StatefulWidget {
  const ScheduleFormScreen({
    super.key,
    required this.trip,
    required this.day,
    required this.existingSchedules,
    required this.onSave,
    this.current,
    this.onLoadLatest,
  });
  final TripDetail trip;
  final String day;
  final List<ScheduleRecord> existingSchedules;
  final Future<ScheduleRecord> Function(
    ScheduleDraft draft,
    ScheduleRecord? current,
  )
  onSave;
  final Future<ScheduleRecord?> Function(String id)? onLoadLatest;
  final ScheduleRecord? current;
  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.current?.title,
  );
  late final TextEditingController _place = TextEditingController(
    text: widget.current?.draft.placeText,
  );
  late final TextEditingController _memo = TextEditingController(
    text: widget.current?.draft.memo,
  );
  late ScheduleRecord? _current = widget.current;
  late String _day = widget.current?.day ?? widget.day;
  late String _start = widget.current?.startTime ?? '10:00';
  late String _end = widget.current?.endTime ?? '11:00';
  late ReservationStatus _reservation =
      widget.current?.draft.reservationStatus ?? ReservationStatus.none;
  bool _isSaving = false,
      _hasChanges = false,
      _canPop = false,
      _hasValidationError = false,
      _hasConflict = false,
      _isLoadingLatest = false;
  String? _error;
  bool get _hasTimeError => timeMinutes(_end) <= timeMinutes(_start);
  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _changed() => setState(() {
    _hasChanges = true;
    _error = null;
  });
  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: scheduleDate(_day),
      firstDate: scheduleDate(widget.trip.startDate),
      lastDate: scheduleDate(widget.trip.endDate),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => _day = scheduleDateString(picked));
    _changed();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final minutes = timeMinutes(isStart ? _start : _end);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: isStart ? ScheduleStrings.start : ScheduleStrings.end,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || picked == null) {
      return;
    }
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _start = value;
      } else {
        _end = value;
      }
    });
    _changed();
  }

  Future<void> _leave() async {
    if (_isSaving || _isLoadingLatest) {
      return;
    }
    final leave =
        !_hasChanges ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text(ScheduleStrings.discardTitle),
                content: const Text(ScheduleStrings.discardHint),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(ScheduleStrings.keepEditing),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(ScheduleStrings.leave),
                  ),
                ],
              ),
            ) ==
            true;
    if (!mounted || !leave) {
      return;
    }
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _loadLatest() async {
    if (_current == null || widget.onLoadLatest == null || _isLoadingLatest) {
      return;
    }
    setState(() => _isLoadingLatest = true);
    try {
      final latest = await widget.onLoadLatest!(_current!.id);
      if (!mounted) {
        return;
      }
      if (latest == null) {
        setState(() => _error = ScheduleStrings.latestMissing);
        return;
      }
      final load = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(ScheduleStrings.latestTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latest.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${ScheduleStrings.dateLabel(latest.day)} · ${ScheduleStrings.timeRange(latest)}',
                ),
                if (latest.draft.memo?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(latest.draft.memo!),
                ],
                if (latest.isLocked) ...[
                  const SizedBox(height: 8),
                  const Text(ScheduleStrings.lockedHint),
                ],
                const SizedBox(height: 16),
                const Text(ScheduleStrings.latestHint),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(ScheduleStrings.keepEditing),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(ScheduleStrings.latestLoad),
            ),
          ],
        ),
      );
      if (!mounted || load != true) {
        return;
      }
      _title.text = latest.title;
      _place.text = latest.draft.placeText ?? '';
      _memo.text = latest.draft.memo ?? '';
      setState(() {
        _current = latest;
        _day = latest.day;
        _start = latest.startTime;
        _end = latest.endTime;
        _reservation = latest.draft.reservationStatus;
        _hasConflict = false;
        _hasChanges = false;
        _error = null;
        _hasValidationError = false;
      });
    } on Object {
      if (mounted) {
        setState(() => _error = ScheduleStrings.loadError);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLatest = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_isSaving || _current?.isLocked == true) {
      return;
    }
    final valid = _form.currentState!.validate() && !_hasTimeError;
    setState(() => _hasValidationError = !valid);
    if (!valid) {
      return;
    }
    FocusScope.of(context).unfocus();
    final draft = ScheduleDraft(
      day: _day,
      startTime: _start,
      endTime: _end,
      title: _title.text.trim(),
      placeText: _place.text.trim().isEmpty ? null : _place.text.trim(),
      memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
      reservationStatus: _reservation,
    );
    final overlaps = overlappingSchedules(
      draft,
      widget.existingSchedules,
      excludingId: _current?.id,
    );
    if (overlaps.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(ScheduleStrings.overlapTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(ScheduleStrings.overlapHint),
                const SizedBox(height: 12),
                for (final item in overlaps.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${item.startTime}–${item.endTime} · ${item.title}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(ScheduleStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(ScheduleStrings.overlapSave),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final saved = await widget.onSave(draft, _current);
      if (!mounted) {
        return;
      }
      setState(() {
        _canPop = true;
        _isSaving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context, saved);
        }
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _hasConflict = error.code == 'CONFLICT' && _current != null;
          _error = _hasConflict
              ? ScheduleStrings.conflict
              : error.displayMessage;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _error = ScheduleStrings.saveError);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<ScheduleRecord>(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        _leave();
      }
    },
    child: Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          _current == null ? ScheduleStrings.add : ScheduleStrings.edit,
        ),
        leading: IconButton(
          tooltip: ScheduleStrings.back,
          onPressed: _isSaving ? null : _leave,
          icon: const Icon(Icons.chevron_left),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _isSaving || _isLoadingLatest,
        child: Form(
          key: _form,
          onChanged: _changed,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('schedule-title'),
                  controller: _title,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: ScheduleStrings.name,
                    hintText: ScheduleStrings.nameHint,
                    counterText: '',
                  ),
                  validator: (value) =>
                      value!.trim().isEmpty || value.trim().length > 100
                      ? ScheduleStrings.nameError
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('schedule-place'),
                  controller: _place,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: ScheduleStrings.place,
                    counterText: '',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) > 100
                      ? ScheduleStrings.placeError
                      : null,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  key: const ValueKey('schedule-date'),
                  onPressed: _pickDay,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(ScheduleStrings.dateLabel(_day)),
                ),
                const SizedBox(height: 20),
                ScheduleTimeFields(
                  start: _start,
                  end: _end,
                  onStart: () => _pickTime(isStart: true),
                  onEnd: () => _pickTime(isStart: false),
                ),
                if (_hasTimeError)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      ScheduleStrings.timeError,
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ExpansionTile(
                    title: const Text(ScheduleStrings.more),
                    subtitle: const Text(ScheduleStrings.moreHint),
                    initiallyExpanded:
                        _reservation != ReservationStatus.none ||
                        _memo.text.isNotEmpty,
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<ReservationStatus>(
                        key: ValueKey('reservation-${_reservation.name}'),
                        initialValue: _reservation,
                        decoration: const InputDecoration(
                          labelText: ScheduleStrings.reservation,
                        ),
                        items: [
                          for (final status in ReservationStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(
                                ScheduleStrings.reservationLabel(status),
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _reservation = value);
                            _changed();
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const ValueKey('schedule-memo'),
                        controller: _memo,
                        maxLength: 500,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: ScheduleStrings.memo,
                        ),
                        validator: (value) => (value?.length ?? 0) > 500
                            ? ScheduleStrings.memoError
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_current?.isLocked == true)
                  const Text(
                    ScheduleStrings.lockedHint,
                    style: TextStyle(color: AppColors.muted),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    key: const ValueKey('schedule-save-error'),
                    style: const TextStyle(color: AppColors.error, height: 1.5),
                  ),
                if (_hasConflict && widget.onLoadLatest != null)
                  OutlinedButton(
                    onPressed: _loadLatest,
                    child: Text(
                      _isLoadingLatest
                          ? ScheduleStrings.loadingLatest
                          : ScheduleStrings.latestAction,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_hasValidationError)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    ScheduleStrings.validationHint,
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              FilledButton(
                key: const ValueKey('schedule-save'),
                onPressed:
                    _isSaving || _isLoadingLatest || _current?.isLocked == true
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(
                  _isSaving ? ScheduleStrings.saving : ScheduleStrings.save,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
