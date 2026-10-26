import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../notification/presentation/notification_bell.dart';
import '../../expense/data/expense_models.dart';
import '../../expense/presentation/expense_form_screen.dart';
import '../../schedule/data/schedule_models.dart';
import '../../schedule/presentation/poll_screens.dart';
import '../../schedule/presentation/schedule_sheets.dart';
import '../../settlement/data/settlement_models.dart';
import '../../settlement/presentation/settlement_screen.dart';
import '../../task/data/task_api.dart';
import '../data/trip_models.dart';
import 'invite_sheet.dart';
import 'trip_settings_screen.dart';
import 'trip_shell.dart';
import 'trip_switch_sheet.dart';

/// BP-HM-001 여행 메인. 여행 전에는 D-day와 준비 현황, 여행 중에는 오늘 요약을 보여 준다.
class TripHomeTab extends StatefulWidget {
  const TripHomeTab({super.key});

  @override
  State<TripHomeTab> createState() => _TripHomeTabState();
}

class _HomeData {
  const _HomeData({
    required this.today,
    required this.mine,
    required this.budget,
    required this.tasks,
    required this.schedules,
    required this.polls,
  });

  final TodaySummary? today;
  final MySettlement mine;
  final Budget budget;
  final List<TripTask> tasks;

  /// 여행 전에만 불러온다 (일정 등록 현황 · 진행 중 투표 카드)
  final List<Schedule> schedules;
  final List<Poll> polls;
}

class _TripHomeTabState extends State<TripHomeTab> {
  int? _revision;
  Future<_HomeData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = TripScope.of(context);
    if (_revision != scope.revision) {
      _revision = scope.revision;
      _future = _load(scope.trip);
    }
  }

  Future<_HomeData> _load(TripDetail trip) async {
    final today = trip.status == TripStatus.live
        ? services.schedules.today(trip.id)
        : Future<TodaySummary?>.value(null);
    final upcoming = trip.status == TripStatus.upcoming;
    final results = await Future.wait<Object?>([
      today,
      services.expenses.mySettlement(trip.id),
      services.expenses.budget(trip.id),
      services.tasks.tasks(trip.id),
      upcoming
          ? services.schedules.schedules(trip.id)
          : Future<List<Schedule>>.value(const []),
      upcoming
          ? services.schedules.polls(trip.id)
          : Future<List<Poll>>.value(const []),
    ]);
    return _HomeData(
      today: results[0] as TodaySummary?,
      mine: results[1]! as MySettlement,
      budget: results[2]! as Budget,
      tasks: results[3]! as List<TripTask>,
      schedules: results[4]! as List<Schedule>,
      polls: results[5]! as List<Poll>,
    );
  }

  Future<void> _refresh() async {
    final scope = TripScope.of(context);
    await scope.reload();
  }

  @override
  Widget build(BuildContext context) {
    final scope = TripScope.of(context);
    final trip = scope.trip;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Cover(trip: trip),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: FutureBuilder<_HomeData>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorView(
                        error: snapshot.error!,
                        onRetry: _refresh,
                      );
                    }
                    final data = snapshot.data;
                    if (data == null) {
                      return const LoadingView();
                    }
                    if (trip.status == TripStatus.upcoming) {
                      return _BeforeTrip(
                        trip: trip,
                        data: data,
                        onChanged: () => setState(() {
                          _future = _load(trip);
                        }),
                      );
                    }
                    return Column(
                      children: [
                        if (data.today != null)
                          _TodayCard(trip: trip, today: data.today!)
                        else
                          _BeforeAfterCard(trip: trip, tasks: data.tasks),
                        const SizedBox(height: 12),
                        _MoneyCard(
                          trip: trip,
                          mine: data.mine,
                          budget: data.budget,
                          onExpenseAdded: () => setState(() {
                            _future = _load(trip);
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.trip});

  final TripDetail trip;

  String get _headline => switch (trip.status) {
    TripStatus.upcoming =>
      trip.dDay == 1
          ? '내일 출발해요'
          : trip.dDay <= 14
          ? '곧 떠나요!'
          : '출발까지 ${trip.dDay}일',
    TripStatus.live => '여행 ${trip.dayNo}일차',
    TripStatus.done => '여행을 마쳤어요',
  };

  String get _sub => switch (trip.status) {
    TripStatus.upcoming =>
      '${Fmt.shortDate(trip.startDate)} – ${Fmt.shortDate(trip.endDate)} · ${trip.nights}박 ${trip.days}일',
    TripStatus.live =>
      'DAY ${trip.dayNo} · ${Fmt.shortDate(DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day + (trip.dayNo ?? 1) - 1))}',
    TripStatus.done => Fmt.range(trip.startDate, trip.endDate),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.coverGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '여행 목록',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  // 여행 이름을 누르면 여행 전환 (BP-CM-001)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showTripSwitcher(context, trip),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              trip.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                shadows: AppColors.coverShadow,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            semanticLabel: '여행 전환',
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '친구 초대',
                    onPressed: () => showInviteSheet(context, trip),
                    icon: const Icon(
                      Icons.person_add_alt_1_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const NotificationBell(color: Colors.white),
                  IconButton(
                    tooltip: '여행 설정',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TripSettingsScreen(scope: TripScope.of(context)),
                      ),
                    ),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sub,
                          style: const TextStyle(
                            color: AppColors.coverText,
                            shadows: AppColors.coverShadow,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _headline,
                          style: const TextStyle(
                            color: Colors.white,
                            shadows: AppColors.coverShadow,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trip.destination,
                          style: const TextStyle(
                            color: AppColors.coverText,
                            shadows: AppColors.coverShadow,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 3,
                    children: [
                      for (final member in trip.members.take(5))
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white.withValues(alpha: .25),
                          child: Text(
                            String.fromCharCode(member.name.runes.first),
                            style: const TextStyle(
                              color: Colors.white,
                              shadows: AppColors.coverShadow,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (trip.members.length > 5)
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white.withValues(alpha: .25),
                          child: Text(
                            '+${trip.members.length - 5}',
                            style: const TextStyle(
                              color: Colors.white,
                              shadows: AppColors.coverShadow,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 34,
              width: double.infinity,
              child: CustomPaint(painter: _SkylinePainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.trip, required this.today});

  final TripDetail trip;
  final TodaySummary today;

  Future<void> _record(BuildContext context, Schedule schedule) async {
    final scope = TripScope.of(context);
    final updated = await showActivitySheet(
      context,
      trip: trip,
      schedule: schedule,
    );
    if (updated != null) {
      await scope.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = TripScope.of(context);
    final current = today.current;
    final focus = current ?? today.next;
    final now = minutesOf(today.localTime);
    final remaining = today.schedules
        .where(
          (s) => s.status != ScheduleStatus.done && minutesOf(s.endTime) > now,
        )
        .where((s) => s.id != focus?.id)
        .toList();
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (current != null)
                    const Pill('● 지금')
                  else if (focus != null)
                    const Pill(
                      '다음 일정',
                      color: AppColors.ink,
                      background: AppColors.background,
                    )
                  else
                    const Pill(
                      '오늘',
                      color: AppColors.ink,
                      background: AppColors.background,
                    ),
                  const Spacer(),
                  Text(
                    current != null
                        ? '${Fmt.time(current.startTime)}부터 · ${Fmt.minutes(now - minutesOf(current.startTime))}째'
                        : focus != null
                        ? '${Fmt.time(focus.startTime)} 시작 · ${Fmt.minutes(minutesOf(focus.startTime) - now)} 뒤'
                        : '현지 ${Fmt.time(today.localTime)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                focus?.title ??
                    (today.total == 0 ? '오늘 일정이 없어요' : '오늘 일정을 모두 마쳤어요'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (focus?.placeText != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        focus!.placeText!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (today.nextFixed != null) ...[
                const SizedBox(height: 16),
                _NextFixed(fixed: today.nextFixed!, now: now),
              ],
              if (today.delayMin > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '오늘 일정이 ${Fmt.minutes(today.delayMin)} 늦어졌어요. '
                          '남은 일정을 확인해 보세요.',
                          style: const TextStyle(fontSize: 12, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (focus != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _record(context, focus),
                        icon: const Icon(Icons.task_alt, size: 18),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.background,
                          foregroundColor: AppColors.ink,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: const Text(
                          '활동 기록',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  if (focus != null) const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => scope.selectTab(TripShell.schedule),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 46),
                      ),
                      icon: const Icon(Icons.calendar_month, size: 17),
                      label: const Text(
                        '일정 보기',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 위 카드에 보인 일정은 빼고 그 뒤 일정만 보여 준다
                  Expanded(
                    child: Text(
                      focus == null ? '오늘 남은 일정' : '그다음 일정',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${today.doneCount}/${today.total} 완료',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (remaining.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    focus == null ? '남은 일정이 없어요' : '위 일정이 오늘 마지막이에요',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              for (final schedule in remaining.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: schedule.isLocked
                            ? AppColors.ink
                            : AppColors.dayTwo,
                        child: Icon(
                          schedule.isLocked
                              ? Icons.lock_outline
                              : Icons.place_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        Fmt.time(schedule.startTime),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          schedule.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextFixed extends StatelessWidget {
  const _NextFixed({required this.fixed, required this.now});

  final NextFixed fixed;
  final int now;

  @override
  Widget build(BuildContext context) {
    final start = minutesOf(fixed.schedule.startTime);
    // 진행 막대: 오늘 0시부터 고정 일정까지 중 지금이 어디쯤인지 (최소 6시간 창)
    final window = (start - now + 180).clamp(360, 24 * 60);
    final progress = 1 - (fixed.minutesUntil / window).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${Fmt.time(fixed.schedule.startTime)} ${fixed.schedule.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                Fmt.minutes(fixed.minutesUntil),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '남음',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: AppColors.ink,
              backgroundColor: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _BeforeAfterCard extends StatelessWidget {
  const _BeforeAfterCard({required this.trip, required this.tasks});

  final TripDetail trip;
  final List<TripTask> tasks;

  @override
  Widget build(BuildContext context) {
    final scope = TripScope.of(context);
    final done = tasks.where((t) => t.isDone).length;
    final upcoming = trip.status == TripStatus.upcoming;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(
                upcoming ? Fmt.dDay(trip.dDay) : '다녀왔어요',
                color: upcoming ? AppColors.primaryText : AppColors.muted,
                background: upcoming
                    ? AppColors.primarySoft
                    : AppColors.background,
              ),
              const Spacer(),
              Text(
                '${trip.nights}박 ${trip.days}일 · ${trip.members.length}명',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            upcoming ? '여행 준비' : '여행 기록',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (upcoming) ...[
            Text(
              tasks.isEmpty ? '아직 준비 목록이 없어요' : '준비 $done/${tasks.length} 완료',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: tasks.isEmpty ? 0 : done / tasks.length,
                minHeight: 5,
                backgroundColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => scope.selectTab(TripShell.schedule),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                  child: const Text('일정', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => scope.selectTab(
                    upcoming ? TripShell.prep : TripShell.expense,
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  child: Text(
                    upcoming ? '준비 목록' : '정산 보기',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 여행 전 (BP-HM-001 A): 출발 D-day · 준비 진행률 → 내가 할 일 → 일정 · 1인 준비 금액 → 진행 중 투표
class _BeforeTrip extends StatelessWidget {
  const _BeforeTrip({
    required this.trip,
    required this.data,
    required this.onChanged,
  });

  final TripDetail trip;
  final _HomeData data;
  final VoidCallback onChanged;

  Future<void> _complete(BuildContext context, TripTask task) async {
    try {
      await services.tasks.update(trip.id, task.id, status: TaskStatus.done);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = TripScope.of(context);
    final team = data.tasks.where((t) => t.scope == TaskScope.team).toList();
    final done = team.where((t) => t.isDone).length;
    final myTodo = team
        .where((t) => t.isAssignedTo(trip.myMemberId) && !t.isDone)
        .toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final plannedDays = {
      for (final s in data.schedules)
        DateTime(s.day.year, s.day.month, s.day.day),
    }.length;
    final fixed = data.schedules.where((s) => s.isLocked).length;
    final openPolls = data.polls.where((p) => p.isVotingOpen).toList();
    final budget = data.budget;
    final rate = budget.todayRate;
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '출발까지',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          Fmt.dDay(trip.dDay),
                          style: const TextStyle(
                            fontSize: 40,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${Fmt.monthDayWeek(trip.startDate)} 출발',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${trip.nights}박 ${trip.days}일 · ${trip.members.length}명',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '준비 진행률',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                  Text(
                    team.isEmpty ? '준비 업무 없음' : '$done / ${team.length} 완료',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: team.isEmpty ? 0 : done / team.length,
                  minHeight: 8,
                  backgroundColor: AppColors.background,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      myTodo.isEmpty ? '내가 할 일' : '내가 할 일 ${myTodo.length}건',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => scope.selectTab(TripShell.prep),
                    child: const Text('준비 전체 ›'),
                  ),
                ],
              ),
              if (myTodo.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 4, 12, 12),
                  child: Text(
                    '맡은 준비 업무를 모두 마쳤어요',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
              for (final task in myTodo.take(3))
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Checkbox(
                        value: false,
                        onChanged: (_) => _complete(context, task),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                [
                                  task.status.label,
                                  if (task.dueDate != null)
                                    '${Fmt.monthDayWeek(task.dueDate!)} 마감',
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (task.daysLeft(today) case final left?)
                        Pill(
                          left < 0 ? '마감 지남' : Fmt.dDay(left),
                          color: left < 0 ? AppColors.error : AppColors.warning,
                          background: left < 0
                              ? const Color(0xFFFDEEF3)
                              : AppColors.warningSoft,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniCard(
                  icon: Icons.calendar_month_outlined,
                  label: '일정',
                  value: '$plannedDays / ${trip.days}일',
                  sub: fixed > 0 ? '고정 일정 $fixed개' : '고정 일정 없음',
                  onTap: () => scope.selectTab(TripShell.schedule),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '1인 준비 금액',
                  value: budget.items.isEmpty
                      ? '예산 없음'
                      : Fmt.krw(budget.perPersonBudgetKrw),
                  // 현지 통화로 얼마를 준비하면 되는지 (원 단위 반올림)
                  sub: budget.items.isEmpty
                      ? '예상 경비를 넣어 보세요'
                      : rate == null
                      ? '${budget.memberCount}명 기준'
                      : '≈ ${Fmt.money((budget.perPersonBudgetKrw / rate.rateToKrw).roundToDouble(), budget.currencyCode)} · ${budget.memberCount}명 기준',
                  onTap: () => scope.selectTab(TripShell.expense),
                ),
              ),
            ],
          ),
        ),
        for (final poll in openPolls.take(1)) ...[
          const SizedBox(height: 12),
          AppCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PollDetailScreen(trip: trip, pollId: poll.id),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.how_to_vote_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '투표 진행 중 ${openPolls.length}건',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          poll.title,
                          if (poll.deadlineAt != null)
                            '${Fmt.monthDayWeek(poll.deadlineAt!.toLocal())} 마감',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (poll.myOptionId == null)
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PollDetailScreen(trip: trip, pollId: poll.id),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('투표하기', style: TextStyle(fontSize: 14)),
                  )
                else
                  const Pill('투표함', icon: Icons.check),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _MoneyCard(
          trip: trip,
          mine: data.mine,
          budget: data.budget,
          onExpenseAdded: onChanged,
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.trip,
    required this.mine,
    required this.budget,
    required this.onExpenseAdded,
  });

  final TripDetail trip;
  final MySettlement mine;
  final Budget budget;
  final VoidCallback onExpenseAdded;

  Future<void> _addExpense(BuildContext context) async {
    final created = await Navigator.of(context).push<ExpenseDetail>(
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(trip: trip)),
    );
    if (created != null) {
      onExpenseAdded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = TripScope.of(context);
    final ratio = budget.usedRatio;
    final balance = mine.balanceKrw;
    final (label, color) = switch (mine.status) {
      SettlementStatus.receive => (
        '받을 돈 ${Fmt.krw(balance)}',
        AppColors.success,
      ),
      SettlementStatus.send => ('보낼 돈 ${Fmt.krw(-balance)}', AppColors.error),
      SettlementStatus.settled => ('정산할 돈 없음', AppColors.muted),
    };
    return AppCard(
      onTap: () => scope.selectTab(TripShell.expense),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ratio == null
                      ? '공동 지출 · ${mine.expenseCount}건'
                      : '공동 지출 ${mine.expenseCount}건 · 예산 ${(ratio * 100).round()}%',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _addExpense(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primaryText,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('지출 등록'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 24,
            runSpacing: 8,
            children: [
              Text(
                Fmt.krw(mine.tripTotalKrw),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '내 정산 · $label',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1).toDouble(),
                minHeight: 5,
                backgroundColor: AppColors.background,
                color: ratio > 1 ? AppColors.error : AppColors.primary,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MySettlementScreen(trip: trip),
                ),
              ),
              child: const Text('계산 근거 보기 ›', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primaryText.withValues(alpha: .16);
    const heights = [
      .3, .7, .45, .9, .55, .35, .8, .5, 1.0, .4, .65, .3, .75, .5, .9, .4, //
    ];
    final width = size.width / heights.length;
    for (int i = 0; i < heights.length; i++) {
      final top = size.height * (1 - heights[i]);
      canvas.drawRect(
        Rect.fromLTWH(i * width, top, width * .68, size.height - top),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) => false;
}
