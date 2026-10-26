import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../notification/presentation/notification_bell.dart';
import '../../schedule/data/schedule_models.dart';
import '../../schedule/presentation/schedule_sheets.dart';
import '../../settlement/data/settlement_models.dart';
import '../../settlement/presentation/settlement_screen.dart';
import '../../task/data/task_api.dart';
import '../data/trip_models.dart';
import 'invite_sheet.dart';
import 'trip_settings_screen.dart';
import 'trip_shell.dart';

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
  });

  final TodaySummary? today;
  final MySettlement mine;
  final Budget budget;
  final List<TripTask> tasks;
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
    final results = await Future.wait<Object?>([
      today,
      services.expenses.mySettlement(trip.id),
      services.expenses.budget(trip.id),
      services.tasks.tasks(trip.id),
    ]);
    return _HomeData(
      today: results[0] as TodaySummary?,
      mine: results[1]! as MySettlement,
      budget: results[2]! as Budget,
      tasks: results[3]! as List<TripTask>,
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
    TripStatus.upcoming => trip.dDay == 1 ? '내일 출발해요' : '출발까지 ${trip.dDay}일',
    TripStatus.live => '여행 ${trip.dayNo}일차',
    TripStatus.done => '여행을 마쳤어요',
  };

  String get _sub => switch (trip.status) {
    TripStatus.upcoming =>
      '${Fmt.dDay(trip.dDay)} · ${Fmt.shortDate(trip.startDate)} 출발',
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
                  Expanded(
                    child: Text(
                      trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
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
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _headline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trip.destination,
                          style: const TextStyle(
                            color: AppColors.coverText,
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

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.trip,
    required this.mine,
    required this.budget,
  });

  final TripDetail trip;
  final MySettlement mine;
  final Budget budget;

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
          Text(
            ratio == null
                ? '공동 지출 · ${mine.expenseCount}건'
                : '공동 지출 · 예산 ${(ratio * 100).round()}%',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
    final paint = Paint()..color = Colors.black.withValues(alpha: .22);
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
