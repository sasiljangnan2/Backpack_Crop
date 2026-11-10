import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../place/data/my_location.dart';
import '../../place/presentation/place_search_sheet.dart';
import '../../schedule/data/schedule_models.dart';
import '../../trip/data/trip_models.dart';
import '../data/replan_models.dart';
import 'plan_compare_screen.dart';

/// BP-AI-002 AI 일정 재구성 — 조건 · 대상 선택, 로딩, 실패.
/// 적용하면 true를 돌려준다 (일정 화면이 다시 불러온다)
class ReplanScreen extends StatefulWidget {
  const ReplanScreen({super.key, required this.trip});

  final TripDetail trip;

  @override
  State<ReplanScreen> createState() => _ReplanScreenState();
}

enum _Phase { form, loading, error }

typedef _Current = ({String name, double? lat, double? lng, bool fromGps});

class _ReplanScreenState extends State<ReplanScreen> {
  TodaySummary? _today;
  Object? _loadError;
  _Current? _current;
  bool _locating = true;
  bool _locationFailed = false;
  final Set<ReplanCondition> _conditions = {};
  final Set<String> _selected = {};
  _Phase _phase = _Phase.form;
  Object? _error;

  TripDetail get trip => widget.trip;

  @override
  void initState() {
    super.initState();
    _load();
    _locate();
  }

  Future<void> _load() async {
    try {
      final today = await services.schedules.today(trip.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _today = today;
        _loadError = null;
        _selected
          ..clear()
          ..addAll(_defaultTargets(today));
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e);
      }
    }
  }

  /// 다시 짤 수 있는 일정: 아직 끝나지 않았고 완료 기록이 없는 일정 (진행 중 포함)
  List<Schedule> _candidates(TodaySummary today) => [
    for (final s in today.schedules)
      if (s.status != ScheduleStatus.done &&
          minutesOf(s.endTime) > minutesOf(today.localTime))
        s,
  ];

  /// 기본값: 지금 이후 ~ 다음 고정 일정 전의 고정이 아닌 일정
  Iterable<String> _defaultTargets(TodaySummary today) {
    final fixed = today.nextFixed?.schedule;
    return _candidates(today)
        .where((s) => !s.isLocked)
        .where(
          (s) =>
              fixed == null ||
              minutesOf(s.startTime) < minutesOf(fixed.startTime),
        )
        .map((s) => s.id);
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationFailed = false;
    });
    final me = await MyLocation.current();
    if (!mounted) {
      return;
    }
    if (me == null) {
      setState(() {
        _locating = false;
        _locationFailed = true;
      });
      return;
    }
    String name = '현재 위치';
    try {
      final place = await services.places.reverse(me.latitude, me.longitude);
      if (place != null) {
        name = place.name;
      }
    } catch (_) {
      // 이름을 못 찾아도 좌표로 추천받는다
    }
    if (mounted) {
      setState(() {
        _current = (
          name: name,
          lat: me.latitude,
          lng: me.longitude,
          fromGps: true,
        );
        _locating = false;
      });
    }
  }

  Future<void> _searchPlace() async {
    final picked = await showPlaceSearch(
      context,
      tripId: trip.id,
      title: '지금 있는 곳',
    );
    if (picked != null && mounted) {
      setState(() {
        _current = (
          name: picked.text,
          lat: picked.place?.lat,
          lng: picked.place?.lng,
          fromGps: false,
        );
        _locationFailed = false;
      });
    }
  }

  Future<void> _recommend() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final current = _current;
      final ordered = [
        for (final s in _today!.schedules)
          if (_selected.contains(s.id)) s.id,
      ];
      final result = await services.replans.recommend(
        trip.id,
        scheduleIds: ordered,
        conditions: _conditions,
        currentName: current?.name,
        currentLat: current?.lat,
        currentLng: current?.lng,
        fromGps: current?.fromGps ?? false,
      );
      if (!mounted) {
        return;
      }
      setState(() => _phase = _Phase.form);
      // 서버가 같은 안 · 지금 일정과 같은 안을 빼서, 남은 안이 없을 수 있다
      if (result.plans.isEmpty) {
        final reason = (result.notice ?? '지금 일정이 이미 고른 조건에 잘 맞아요.')
            .replaceFirst('바꿀 만한 추천안이 없어요. ', '');
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('바꿀 만한 추천안이 없어요'),
            content: Text(
              '$reason\n조건을 바꾸거나 다시 짤 일정을 더 골라 보세요.',
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        return;
      }
      final outcome = await Navigator.of(context).push<CompareOutcome>(
        MaterialPageRoute(
          builder: (_) => PlanCompareScreen(trip: trip, result: result),
        ),
      );
      if (!mounted) {
        return;
      }
      switch (outcome) {
        case CompareOutcome.applied:
          Navigator.pop(context, true);
        case CompareOutcome.retry:
          await _load();
          if (mounted) {
            _recommend();
          }
        case null:
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI 일정 재구성'),
            Text(
              '고정 일정 유지',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
      body: switch (_phase) {
        _Phase.loading => _Loading(today: _today, current: _current),
        _Phase.error => _Failure(
          error: _error!,
          onRetry: _recommend,
          onClose: () => Navigator.pop(context),
        ),
        _Phase.form => _form(),
      },
      bottomNavigationBar: _phase == _Phase.form && _today != null && _canReplan
          ? BottomActionBar(
              child: FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _recommend,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('추천안 받기'),
              ),
            )
          : null,
    );
  }

  bool get _canReplan => _today?.tripStatus == TripStatus.live;

  Widget _form() {
    final today = _today;
    if (today == null) {
      return _loadError == null
          ? const LoadingView()
          : ErrorView(error: _loadError!, onRetry: _load);
    }
    if (!_canReplan) {
      return const EmptyView(
        icon: Icons.event_busy_outlined,
        title: '여행 중인 날에만 다시 짤 수 있어요',
        message: '여행 기간이 되면 그날 남은 일정을 AI가 다시 짜 드려요.',
      );
    }
    final candidates = _candidates(today);
    final placesToday = [
      for (final s in today.schedules)
        if (s.hasPlace) s,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (_locationFailed) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 18,
                  color: AppColors.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '현재 위치를 확인하지 못했어요.\n위치 권한이 꺼져 있거나 신호가 약해요. 지금 있는 장소를 직접 입력해 주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _searchPlace,
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
            icon: const Icon(Icons.search),
            label: const Text('장소 검색으로 직접 입력'),
          ),
          if (placesToday.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              '오늘 일정 장소에서 고르기',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in placesToday)
                  ActionChip(
                    avatar: Icon(
                      s.status == ScheduleStatus.inProgress
                          ? Icons.schedule
                          : Icons.place_outlined,
                      size: 16,
                    ),
                    label: Text(
                      '${s.placeText ?? s.title}${s.status == ScheduleStatus.inProgress ? ' · 진행 중' : ''}',
                    ),
                    onPressed: () => setState(() {
                      _current = (
                        name: s.placeText ?? s.title,
                        lat: s.placeLat,
                        lng: s.placeLng,
                        fromGps: false,
                      );
                      _locationFailed = false;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
        ],
        _ContextCard(
          today: today,
          current: _current,
          locating: _locating,
          onChangePlace: _searchPlace,
        ),
        const SizedBox(height: 22),
        const Text(
          '조건',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in ReplanCondition.values)
              FilterChip(
                selected: _conditions.contains(c),
                label: Text(c.label),
                onSelected: (on) => setState(
                  () => on ? _conditions.add(c) : _conditions.remove(c),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Text(
              '다시 짤 일정',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '${_selected.length}개 선택',
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '오늘 남은 일정이 없어요.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        for (final s in candidates)
          _TargetRow(
            schedule: s,
            selected: _selected.contains(s.id),
            onChanged: s.isLocked
                ? null
                : (on) => setState(
                    () => on ? _selected.add(s.id) : _selected.remove(s.id),
                  ),
          ),
        const SizedBox(height: 14),
        const Text(
          'AI 추천에는 일정 이름 · 장소 · 시간만 보내요. 고정 일정은 바뀌지 않아요.',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// "AI가 읽은 현재 상황"
class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.today,
    required this.current,
    required this.locating,
    required this.onChangePlace,
  });

  final TodaySummary today;
  final _Current? current;
  final bool locating;
  final VoidCallback onChangePlace;

  @override
  Widget build(BuildContext context) {
    final fixed = today.nextFixed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI가 읽은 현재 상황',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primaryText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _Row(
            label: '현재 장소',
            child: locating
                ? const Row(
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('위치 확인 중…'),
                    ],
                  )
                : InkWell(
                    onTap: onChangePlace,
                    child: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          current?.name ?? '마지막 일정 장소',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (current?.fromGps ?? false)
                          const Pill(
                            'GPS',
                            color: AppColors.muted,
                            background: Colors.white,
                          )
                        else if (current != null)
                          const Pill(
                            '직접 입력',
                            color: AppColors.muted,
                            background: Colors.white,
                          ),
                        const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
          ),
          _Row(
            label: '진행 활동',
            child: Text(
              '${today.doneCount}건 완료${today.delayMin > 0 ? ' · +${Fmt.minutes(today.delayMin)} 늦어짐' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          _Row(
            label: '남은 시간',
            child: Text(
              fixed == null
                  ? '오늘 고정 일정 없음'
                  : '고정 일정까지 ${Fmt.minutes(fixed.minutesUntil)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (fixed != null)
            _Row(
              label: '고정 일정',
              child: Text(
                '${Fmt.time(fixed.schedule.startTime)} ${fixed.schedule.title}'
                '${fixed.schedule.reservationStatus == ReservationStatus.confirmed ? ' (예약)' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.schedule,
    required this.selected,
    this.onChanged,
  });

  final Schedule schedule;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final locked = schedule.isLocked;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: locked
                  ? const Icon(Icons.lock_outline, color: AppColors.muted)
                  : Checkbox(
                      value: selected,
                      onChanged: (v) => onChanged?.call(v ?? false),
                    ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                Fmt.time(schedule.startTime),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    locked
                        ? '고정 일정 · 바뀌지 않아요'
                        : schedule.status == ScheduleStatus.inProgress
                        ? '진행 중'
                        : (schedule.placeText ??
                              '${schedule.durationMinutes}분'),
                    style: TextStyle(
                      fontSize: 12,
                      color: locked ? AppColors.error : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 추천 생성 중 (스토리보드 BP-AI-002 A): 진행 단계 + 결과 자리 스켈레톤
class _Loading extends StatelessWidget {
  const _Loading({required this.today, required this.current});

  final TodaySummary? today;
  final _Current? current;

  @override
  Widget build(BuildContext context) {
    final fixed = today?.nextFixed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          fixed == null
              ? '남은 시간에 맞춰\n일정을 다시 짜고 있어요'
              : '남은 ${Fmt.minutes(fixed.minutesUntil)}에 맞춰\n일정을 다시 짜고 있어요',
          style: const TextStyle(
            fontSize: 22,
            height: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        AppCard(
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Step(
                done: true,
                text: '현재 장소 확인 · ${current?.name ?? '마지막 일정 장소'}',
              ),
              _Step(
                done: true,
                text: fixed == null
                    ? '고정 일정 유지'
                    : '고정 일정 유지 · ${Fmt.time(fixed.schedule.startTime)} ${fixed.schedule.title}',
              ),
              const _Step(done: false, text: '추천안을 만들고 있습니다...'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 2; i++) ...[
          Container(
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.text});

  final bool done;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          done
              ? const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: AppColors.primary,
                )
              : const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 추천 실패 (BP-AI-002 B): 원인 + "지금 일정은 그대로 유지돼요"
class _Failure extends StatelessWidget {
  const _Failure({
    required this.error,
    required this.onRetry,
    required this.onClose,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).displayMessage
        : 'AI 서버 응답이 늦어지고 있어요.';
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFDEEF3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 36,
                color: AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '추천을 받지 못했어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          const Text(
            '지금 일정은 그대로 유지돼요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('일정 직접 수정'),
          ),
          TextButton(
            onPressed: onClose,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('기존 일정 유지하고 닫기'),
          ),
        ],
      ),
    );
  }
}
