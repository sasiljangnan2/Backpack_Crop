import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../data/schedule_models.dart';

Future<TimeOfDay?> pickTime(
  BuildContext context,
  TimeOfDay initial,
  String help,
) => showTimePicker(
  context: context,
  initialTime: initial,
  helpText: help,
  initialEntryMode: TimePickerEntryMode.dial,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
    child: child!,
  ),
);

/// BP-SC-002 일정 등록 · 수정. 저장하면 저장된 일정을 돌려준다.
Future<Schedule?> showScheduleForm(
  BuildContext context, {
  required TripDetail trip,
  required DateTime day,
  Schedule? existing,
}) => showModalBottomSheet<Schedule>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _ScheduleForm(trip: trip, day: day, existing: existing),
);

class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm({required this.trip, required this.day, this.existing});

  final TripDetail trip;
  final DateTime day;
  final Schedule? existing;

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _place = TextEditingController(text: widget.existing?.placeText);
  late final _memo = TextEditingController(text: widget.existing?.memo);
  late DateTime _day = widget.existing?.day ?? widget.day;
  late TimeOfDay _start =
      widget.existing?.startTime ?? const TimeOfDay(hour: 10, minute: 0);
  late TimeOfDay _end =
      widget.existing?.endTime ?? const TimeOfDay(hour: 11, minute: 0);
  late ReservationStatus _reservation =
      widget.existing?.reservationStatus ?? ReservationStatus.none;
  late bool _locked = widget.existing?.isLocked ?? false;
  bool _busy = false;
  String? _error;
  Map<String, String>? _overlap;

  bool get _editing => widget.existing != null;
  bool get _timeValid => minutesOf(_end) > minutesOf(_start);

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await pickTime(context, _start, '시작 시간');
    if (picked == null) {
      return;
    }
    final duration = (minutesOf(_end) - minutesOf(_start)).clamp(30, 600);
    setState(() {
      _start = picked;
      final end = minutesOf(picked) + duration;
      _end = end >= 24 * 60
          ? const TimeOfDay(hour: 23, minute: 59)
          : timeOfMinutes(end);
      _error = null;
      _overlap = null;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await pickTime(context, _end, '종료 시간');
    if (picked != null) {
      setState(() {
        _end = picked;
        _error = null;
        _overlap = null;
      });
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || !_timeValid) {
      setState(
        () => _error = _title.text.trim().isEmpty
            ? '일정 이름을 입력해 주세요.'
            : '종료 시간은 시작 시간보다 늦어야 해요.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _overlap = null;
    });
    final tripId = widget.trip.id;
    // 고정을 풀고 고치다 실패하면 다시 고정해 둔다 (원래 상태로 되돌린다)
    int? relockVersion;
    try {
      final Schedule saved;
      final existing = widget.existing;
      if (existing == null) {
        saved = await services.schedules.create(
          tripId,
          day: _day,
          start: _start,
          end: _end,
          title: _title.text.trim(),
          placeText: _place.text.trim().isEmpty ? null : _place.text.trim(),
          memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
          reservation: _reservation,
          locked: _locked,
        );
      } else {
        var version = existing.version;
        // 고정된 일정은 고정을 먼저 풀고 고친다 (서버 규칙)
        if (existing.isLocked) {
          final unlocked = await services.schedules.update(
            tripId,
            existing.id,
            version: version,
            locked: false,
          );
          version = unlocked.version;
          relockVersion = version;
        }
        saved = await services.schedules.update(
          tripId,
          existing.id,
          version: version,
          day: _day,
          start: _start,
          end: _end,
          title: _title.text.trim(),
          placeText: _place.text.trim(),
          memo: _memo.text.trim(),
          reservation: _reservation,
          locked: _locked,
        );
      }
      if (mounted) {
        Navigator.pop(context, saved);
      }
    } on ApiException catch (e) {
      final existing = widget.existing;
      if (relockVersion != null && existing != null) {
        try {
          await services.schedules.update(
            tripId,
            existing.id,
            version: relockVersion,
            locked: true,
          );
        } on ApiException {
          // 다시 고정하지 못해도 원래 오류를 보여 준다
        }
      }
      if (!mounted) {
        return;
      }
      switch (e.code) {
        case 'SCHEDULE_OVERLAP':
          setState(() => _overlap = e.details);
        case 'VERSION_CONFLICT':
          showSnack(context, e.message);
          Navigator.pop(context);
        default:
          setState(() => _error = e.displayMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final overlap = _overlap;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editing ? '일정 수정' : '일정 추가',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              const FieldLabel('일정 이름', required: true),
              TextField(
                controller: _title,
                autofocus: !_editing,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '예: 구로몬 시장',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('장소'),
              TextField(
                controller: _place,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: '예: 난바',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('날짜 · 시간', required: true),
              DropdownButtonFormField<DateTime>(
                initialValue: trip.dates.firstWhere(
                  (d) => sameDay(d, _day),
                  orElse: () => trip.dates.first,
                ),
                items: [
                  for (final date in trip.dates)
                    DropdownMenuItem(
                      value: date,
                      child: Text(
                        'DAY ${trip.dayNumberOf(date)} · ${Fmt.shortDate(date)}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _day = value ?? _day;
                  _overlap = null;
                }),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: '시작',
                      time: _start,
                      onTap: _pickStart,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('–'),
                  ),
                  Expanded(
                    child: _TimeButton(
                      label: '종료',
                      time: _end,
                      onTap: _pickEnd,
                      error: !_timeValid,
                    ),
                  ),
                ],
              ),
              if (overlap != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDEEF3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "'${overlap['title']}' ${overlap['startTime']}–${overlap['endTime']} 일정과 시간이 겹쳐요."
                          '${(int.tryParse(overlap['overlapCount'] ?? '1') ?? 1) > 1 ? ' (겹친 일정 ${overlap['overlapCount']}개)' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const FieldLabel('예약'),
              SegmentedButton<ReservationStatus>(
                segments: const [
                  ButtonSegment(
                    value: ReservationStatus.none,
                    label: Text('없음'),
                  ),
                  ButtonSegment(
                    value: ReservationStatus.pending,
                    label: Text('확인 중'),
                  ),
                  ButtonSegment(
                    value: ReservationStatus.confirmed,
                    label: Text('확정'),
                  ),
                ],
                selected: {_reservation},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _reservation = value.first),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _locked,
                onChanged: (value) => setState(() => _locked = value),
                title: const Text(
                  '시간 고정',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  '예약처럼 바꿀 수 없는 일정이에요. 고정을 풀어야 수정·삭제할 수 있어요.',
                  style: TextStyle(fontSize: 12),
                ),
                secondary: const Icon(Icons.lock_outline),
              ),
              const FieldLabel('메모'),
              TextField(
                controller: _memo,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '예: 입장권은 현장 구매',
                  counterText: '',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_editing ? '저장' : '추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
    this.error = false,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: error ? AppColors.error : AppColors.border),
        foregroundColor: error ? AppColors.error : AppColors.ink,
      ),
      child: Text(
        '$label ${Fmt.time(time)}',
        style: const TextStyle(fontSize: 15),
      ),
    );
  }
}

/// BP-AI-004 활동 기록. 실제로 시작·종료한 시각을 남기면 지연이 다시 계산된다.
Future<Schedule?> showActivitySheet(
  BuildContext context, {
  required TripDetail trip,
  required Schedule schedule,
}) => showModalBottomSheet<Schedule>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _ActivitySheet(trip: trip, schedule: schedule),
);

class _ActivitySheet extends StatefulWidget {
  const _ActivitySheet({required this.trip, required this.schedule});

  final TripDetail trip;
  final Schedule schedule;

  @override
  State<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<_ActivitySheet> {
  late TimeOfDay _start =
      widget.schedule.activity?.actualStartTime ?? widget.schedule.startTime;
  late TimeOfDay _end =
      widget.schedule.activity?.actualEndTime ?? widget.schedule.endTime;
  bool _busy = false;

  /// 여행지의 지금 시각. 그날 일정일 때만 서버에서 받아 빠른 선택에 쓴다
  TimeOfDay? _now;

  int get _delay =>
      (minutesOf(_end) - minutesOf(widget.schedule.endTime)).clamp(0, 24 * 60);

  bool get _endAfterNow => _now != null && minutesOf(_end) > minutesOf(_now!);

  @override
  void initState() {
    super.initState();
    _loadNow();
  }

  Future<void> _loadNow() async {
    try {
      final today = await services.schedules.today(widget.trip.id);
      if (mounted && sameDay(today.date, widget.schedule.day)) {
        setState(() => _now = today.localTime);
      }
    } catch (_) {
      // 빠른 선택만 숨긴다
    }
  }

  void _quickEnd(int minutesAgo) {
    final now = _now!;
    final minutes = (minutesOf(now) - minutesAgo).clamp(
      minutesOf(_start),
      minutesOf(now),
    );
    setState(() => _end = timeOfMinutes(minutes));
  }

  Future<void> _save() async {
    if (minutesOf(_end) < minutesOf(_start)) {
      showSnack(context, '실제 종료는 실제 시작과 같거나 늦어야 해요.');
      return;
    }
    if (_endAfterNow) {
      showSnack(context, '실제 종료는 지금 이후로 기록할 수 없어요.');
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await services.schedules.recordActivity(
        widget.trip.id,
        widget.schedule.id,
        start: _start,
        end: _end,
      );
      if (mounted) {
        Navigator.pop(context, saved);
        showSnack(
          context,
          _delay > 0 ? '기록했어요 · ${Fmt.minutes(_delay)} 지연' : '기록했어요',
        );
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await services.schedules.cancelActivity(
        widget.trip.id,
        widget.schedule.id,
      );
      final refreshed = await services.schedules.schedules(
        widget.trip.id,
        day: widget.schedule.day,
      );
      if (mounted) {
        Navigator.pop(
          context,
          refreshed.firstWhere(
            (s) => s.id == widget.schedule.id,
            orElse: () => widget.schedule,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '활동 기록',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Text(
              schedule.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '계획 ${Fmt.time(schedule.startTime)}–${Fmt.time(schedule.endTime)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: '실제 시작',
                    time: _start,
                    onTap: () async {
                      final picked = await pickTime(context, _start, '실제 시작');
                      if (picked != null) {
                        setState(() => _start = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeButton(
                    label: '실제 종료',
                    time: _end,
                    error: minutesOf(_end) < minutesOf(_start) || _endAfterNow,
                    onTap: () async {
                      final picked = await pickTime(context, _end, '실제 종료');
                      if (picked != null) {
                        setState(() => _end = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_now != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final (label, ago) in const [
                    ('지금', 0),
                    ('10분 전', 10),
                    ('30분 전', 30),
                  ]) ...[
                    Expanded(
                      child: ActionChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(label, textAlign: TextAlign.center),
                        ),
                        onPressed: () => _quickEnd(ago),
                      ),
                    ),
                    if (ago != 30) const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _delay > 0
                  ? '계획보다 ${Fmt.minutes(_delay)} 늦게 끝났어요'
                  : '계획 시간 안에 끝났어요',
              style: TextStyle(
                fontSize: 13,
                color: _delay > 0 ? AppColors.warning : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('완료로 기록'),
            ),
            if (schedule.activity != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _cancel,
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text('기록 취소'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
