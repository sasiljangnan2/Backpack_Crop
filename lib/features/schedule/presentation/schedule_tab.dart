import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../../trip/presentation/trip_shell.dart';
import '../data/schedule_models.dart';
import 'poll_screens.dart';
import 'schedule_sheets.dart';

/// BP-SC-001 날짜별 일정
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> with TripTabRefresh {
  DateTime? _day;
  List<Schedule>? _schedules;
  List<Poll> _openPolls = const [];
  Object? _error;
  String? _tripId;

  @override
  int get tabIndex => TripShell.schedule;

  @override
  void onTabShown() => _load();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final trip = TripScope.of(context).trip;
    if (_tripId != trip.id) {
      _tripId = trip.id;
      _day = _initialDay(trip);
      _load();
    }
  }

  // 여행 중이면 오늘, 아니면 첫날
  DateTime _initialDay(TripDetail trip) {
    final now = DateTime.now();
    for (final date in trip.dates) {
      if (sameDay(date, now)) {
        return date;
      }
    }
    return trip.dates.first;
  }

  Future<void> _load() async {
    final trip = TripScope.of(context).trip;
    try {
      final results = await Future.wait<Object>([
        services.schedules.schedules(trip.id),
        services.schedules.polls(trip.id),
      ]);
      if (mounted) {
        setState(() {
          _schedules = results[0] as List<Schedule>;
          _openPolls = (results[1] as List<Poll>)
              .where((p) => p.isVotingOpen)
              .toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _add() async {
    final trip = TripScope.of(context).trip;
    final saved = await showScheduleForm(context, trip: trip, day: _day!);
    if (saved != null) {
      setState(() => _day = saved.day);
      await _load();
    }
  }

  Future<void> _openActions(Schedule schedule) async {
    final trip = TripScope.of(context).trip;
    final action = await showAppSheet<String>(
      context,
      title: schedule.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${Fmt.shortDate(schedule.day)} ${Fmt.time(schedule.startTime)}–${Fmt.time(schedule.endTime)}'
            '${schedule.placeText == null ? '' : ' · ${schedule.placeText}'}',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (schedule.memo != null) ...[
            const SizedBox(height: 10),
            Text(
              schedule.memo!,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ],
          if (schedule.activity != null) ...[
            const SizedBox(height: 10),
            Text(
              '실제 ${Fmt.time(schedule.activity!.actualStartTime)}–${Fmt.time(schedule.activity!.actualEndTime)}'
              '${schedule.activity!.delayMin > 0 ? ' · ${Fmt.minutes(schedule.activity!.delayMin)} 지연' : ''}'
              ' · ${schedule.activity!.recordedBy.name} 기록',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.task_alt,
            label: schedule.activity == null ? '활동 기록' : '활동 기록 수정',
            value: 'record',
          ),
          _ActionTile(icon: Icons.edit_outlined, label: '수정', value: 'edit'),
          _ActionTile(
            icon: schedule.isLocked
                ? Icons.lock_open_outlined
                : Icons.lock_outline,
            label: schedule.isLocked ? '고정 풀기' : '시간 고정',
            value: 'lock',
          ),
          _ActionTile(
            icon: Icons.delete_outline,
            label: '삭제',
            value: 'delete',
            color: AppColors.error,
          ),
        ],
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    try {
      switch (action) {
        case 'record':
          if (await showActivitySheet(
                context,
                trip: trip,
                schedule: schedule,
              ) ==
              null) {
            return;
          }
        case 'edit':
          if (await showScheduleForm(
                context,
                trip: trip,
                day: schedule.day,
                existing: schedule,
              ) ==
              null) {
            return;
          }
        case 'lock':
          await services.schedules.update(
            trip.id,
            schedule.id,
            version: schedule.version,
            locked: !schedule.isLocked,
          );
          if (mounted) {
            showSnack(context, schedule.isLocked ? '고정을 풀었어요.' : '시간을 고정했어요.');
          }
        case 'delete':
          if (schedule.isLocked) {
            showSnack(context, '고정된 일정이에요. 고정을 먼저 풀어 주세요.');
            return;
          }
          final ok = await confirm(
            context,
            title: '일정을 삭제할까요?',
            message: "'${schedule.title}' 일정과 활동 기록이 지워져요.",
            confirmLabel: '삭제',
            destructive: true,
          );
          if (!ok) {
            return;
          }
          await services.schedules.delete(trip.id, schedule.id);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final trip = TripScope.of(context).trip;
    final day = _day ?? trip.startDate;
    final schedules = _schedules;
    final ofDay =
        schedules?.where((s) => sameDay(s.day, day)).toList() ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PollListScreen(trip: trip),
                ),
              );
              _load();
            },
            icon: const Icon(Icons.how_to_vote_outlined, size: 20),
            label: const Text('장소 투표'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: schedules == null ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: trip.dates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final date = trip.dates[index];
                return _DayTab(
                  dayNo: index + 1,
                  date: date,
                  selected: sameDay(date, day),
                  isToday: sameDay(date, DateTime.now()),
                  onTap: () => setState(() => _day = date),
                );
              },
            ),
          ),
          Expanded(
            child: schedules == null
                ? (_error == null
                      ? const LoadingView()
                      : ErrorView(error: _error!, onRetry: _load))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      children: [
                        if (_openPolls.isNotEmpty) ...[
                          AppCard(
                            color: AppColors.primarySoft,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PollListScreen(trip: trip),
                                ),
                              );
                              _load();
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.how_to_vote,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '투표 중인 장소 ${_openPolls.length}개 · ${_openPolls.first.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                          child: Text(
                            'DAY ${trip.dayNumberOf(day)} · ${Fmt.longDate(day)}',
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (ofDay.isEmpty)
                          AppCard(
                            child: EmptyView(
                              icon: Icons.event_note_outlined,
                              title: '이날 일정이 없어요',
                              message: '가고 싶은 곳을 추가해 보세요.',
                              action: OutlinedButton.icon(
                                onPressed: _add,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(160, 44),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('일정 추가'),
                              ),
                            ),
                          )
                        else
                          AppCard(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                for (int i = 0; i < ofDay.length; i++)
                                  _ScheduleRow(
                                    schedule: ofDay[i],
                                    index: i + 1,
                                    dayNo: trip.dayNumberOf(day),
                                    isLast: i == ofDay.length - 1,
                                    onTap: () => _openActions(ofDay[i]),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.schedule,
    required this.index,
    required this.isLast,
    required this.onTap,
    this.dayNo = 1,
  });

  final Schedule schedule;
  final int index;
  final bool isLast;
  final VoidCallback onTap;

  /// 번호 핀 색 (일차별 색)
  final int dayNo;

  @override
  Widget build(BuildContext context) {
    final done = schedule.status == ScheduleStatus.done;
    final now = schedule.status == ScheduleStatus.inProgress;
    // 번호 핀: 고정 = 검정 자물쇠, 완료 = 회색, 나머지 = 일차 색 (스토리보드 BC-003 ③)
    final markerColor = schedule.isLocked
        ? AppColors.ink
        : done
        ? AppColors.disabled
        : AppColors.day(dayNo);
    // 왼쪽 선: 고정 = 검정, 진행 중 = 주요 색
    final edge = schedule.isLocked
        ? AppColors.ink
        : now
        ? AppColors.primary
        : Colors.transparent;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: edge, width: 4)),
          color: now ? AppColors.primarySoft.withValues(alpha: .5) : null,
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.time(schedule.startTime),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    Fmt.time(schedule.endTime),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 12,
              backgroundColor: markerColor,
              child: schedule.isLocked
                  ? const Icon(
                      Icons.lock_outline,
                      size: 13,
                      color: Colors.white,
                    )
                  : done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '$index',
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: done ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                  if (schedule.placeText != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      schedule.placeText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (now) const Pill('● 지금'),
                      if (done)
                        Pill(
                          schedule.activity!.delayMin > 0
                              ? '완료 · ${Fmt.minutes(schedule.activity!.delayMin)} 지연'
                              : '완료',
                          color: schedule.activity!.delayMin > 0
                              ? AppColors.warning
                              : AppColors.success,
                          background: schedule.activity!.delayMin > 0
                              ? AppColors.warningSoft
                              : AppColors.successSoft,
                        ),
                      if (schedule.reservationStatus ==
                          ReservationStatus.confirmed)
                        const Pill(
                          '예약 확정',
                          color: AppColors.success,
                          background: AppColors.successSoft,
                          icon: Icons.check,
                        ),
                      if (schedule.reservationStatus ==
                          ReservationStatus.pending)
                        const Pill(
                          '예약 대기',
                          color: AppColors.warning,
                          background: AppColors.warningSoft,
                        ),
                      if (schedule.isLocked)
                        const Pill(
                          '고정',
                          color: Colors.white,
                          background: AppColors.ink,
                          icon: Icons.lock_outline,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// DAY 탭 (스토리보드 BC-004 ④): 선택한 날만 검정, 일차별 색 점, 여행 당일은 "오늘"
class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.dayNo,
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final int dayNo;
  final DateTime date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.ink : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.ink : AppColors.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.day(dayNo),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'DAY $dayNo',
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isToday ? '오늘' : Fmt.shortDate(date),
                  style: TextStyle(
                    color: selected ? Colors.white70 : AppColors.muted,
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: () => Navigator.pop(context, value),
    );
  }
}
