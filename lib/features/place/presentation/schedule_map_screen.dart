import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../schedule/data/schedule_models.dart';
import '../../schedule/presentation/schedule_sheets.dart';
import '../../schedule/presentation/schedule_tab.dart';
import '../../trip/data/trip_models.dart';
import '../data/my_location.dart';
import '../data/place_models.dart';
import 'schedule_map.dart';

/// BP-SC-004 일정 지도: 그날 동선 전체, 핀 선택 → 장소 카드, 지도 앱에서 열기
class ScheduleMapScreen extends StatefulWidget {
  const ScheduleMapScreen({super.key, required this.trip, required this.day});

  final TripDetail trip;
  final DateTime day;

  @override
  State<ScheduleMapScreen> createState() => _ScheduleMapScreenState();
}

class _ScheduleMapScreenState extends State<ScheduleMapScreen> {
  final _map = ScheduleMapController();
  late DateTime _day = widget.day;
  List<Schedule>? _schedules;
  DayRoute _route = DayRoute.empty;
  Object? _error;
  String? _selectedId;
  LatLng? _me;
  bool _tilesFailed = false;

  TripDetail get trip => widget.trip;

  bool get _live => trip.dates.any((d) => sameDay(d, DateTime.now()));

  @override
  void initState() {
    super.initState();
    _load();
    // 여행 중이고 이미 위치를 허락했을 때만 처음부터 내 위치를 보여 준다
    if (_live) {
      MyLocation.current(ask: false).then((me) {
        if (mounted && me != null) {
          setState(() => _me = me);
        }
      });
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        services.schedules.schedules(trip.id, day: _day),
        services.places
            .dayRoute(trip.id, _day)
            .catchError((_) => DayRoute.empty),
      ]);
      if (mounted) {
        setState(() {
          _schedules = results[0] as List<Schedule>;
          _route = results[1] as DayRoute;
          _error = null;
          if (_selectedId != null &&
              !_schedules!.any((s) => s.id == _selectedId)) {
            _selectedId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  void _changeDay(DateTime day) {
    setState(() {
      _day = day;
      _schedules = null;
      _selectedId = null;
      _route = DayRoute.empty;
    });
    _load();
  }

  Future<void> _goToMe() async {
    final me = await MyLocation.current();
    if (!mounted) {
      return;
    }
    if (me == null) {
      showSnack(context, '위치를 확인하지 못했어요. 위치 권한과 GPS를 켜 주세요.');
      return;
    }
    setState(() => _me = me);
    _map.moveTo(me, zoom: 16);
  }

  void _select(String id) {
    final schedules = _schedules ?? const [];
    if (id.isEmpty) {
      setState(() => _selectedId = null);
      return;
    }
    final s = schedules.firstWhere((s) => s.id == id);
    setState(() => _selectedId = id);
    _map.moveTo(ScheduleMapView.pointOf(s));
  }

  @override
  Widget build(BuildContext context) {
    final schedules = _schedules;
    final dayNo = trip.dayNumberOf(_day);
    final placed = schedules?.where((s) => s.hasPlace).toList() ?? const [];
    final locked = schedules?.where((s) => s.isLocked).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dayNo일차 지도'),
            Text(
              '${Fmt.monthDayWeek(_day)} · ${placed.length}곳${locked > 0 ? ' · 고정 $locked' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '목록으로 보기',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.format_list_bulleted),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: trip.dates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => DayTabChip(
                dayNo: i + 1,
                date: trip.dates[i],
                selected: sameDay(trip.dates[i], _day),
                isToday: sameDay(trip.dates[i], DateTime.now()),
                onTap: () => _changeDay(trip.dates[i]),
              ),
            ),
          ),
          Expanded(
            child: schedules == null
                ? (_error == null
                      ? const LoadingView()
                      : ErrorView(error: _error!, onRetry: _load))
                : placed.isEmpty
                ? EmptyView(
                    icon: Icons.map_outlined,
                    title: '지도에 표시할 장소가 없어요',
                    message: '일정에 장소를 검색해 넣으면 동선이 보여요.',
                    action: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('목록으로'),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: ScheduleMapView(
                          key: ValueKey(_day),
                          schedules: schedules,
                          dayNo: dayNo,
                          selectedId: _selectedId,
                          onSelect: _select,
                          myLocation: _me,
                          controller: _map,
                          fitPadding: const EdgeInsets.fromLTRB(
                            40,
                            40,
                            40,
                            200,
                          ),
                          onTilesFailed: () {
                            if (mounted) {
                              setState(() => _tilesFailed = true);
                            }
                          },
                        ),
                      ),
                      if (_tilesFailed)
                        Positioned(
                          left: 16,
                          right: 16,
                          top: 12,
                          child: Material(
                            color: AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.wifi_off,
                                color: AppColors.warning,
                              ),
                              title: const Text('지도를 불러오지 못했어요'),
                              trailing: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('목록으로 보기'),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 16,
                        bottom: _selectedId == null ? 168 : 232,
                        child: FloatingActionButton.small(
                          heroTag: 'me',
                          tooltip: '내 위치',
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.success,
                          onPressed: _goToMe,
                          child: const Icon(Icons.my_location),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _selectedId == null
                            ? _Summary(
                                schedules: schedules,
                                route: _route,
                                dayNo: dayNo,
                                onSelect: _select,
                              )
                            : _PlaceCard(
                                trip: trip,
                                schedules: schedules,
                                schedule: schedules.firstWhere(
                                  (s) => s.id == _selectedId,
                                ),
                                dayNo: dayNo,
                                me: _me,
                                onEdited: _load,
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.disabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// 하단 요약: 총 이동 거리 · 시간 + 장소 순서 칩
class _Summary extends StatelessWidget {
  const _Summary({
    required this.schedules,
    required this.route,
    required this.dayNo,
    required this.onSelect,
  });

  final List<Schedule> schedules;
  final DayRoute route;
  final int dayNo;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '그날 동선',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (route.missingPlaceCount > 0)
                Text(
                  '장소 없는 일정 ${route.missingPlaceCount}개',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                route.legs.isEmpty ? '장소가 하나라 이동이 없어요' : route.summary,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < schedules.length; i++)
                  if (schedules[i].hasPlace)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: CircleAvatar(
                          backgroundColor: schedules[i].isLocked
                              ? AppColors.ink
                              : schedules[i].status == ScheduleStatus.done
                              ? AppColors.disabled
                              : AppColors.day(dayNo),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        label: Text(
                          schedules[i].title,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => onSelect(schedules[i].id),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 장소 카드: 시간 · 장소 · 상태, 현재 위치에서 걸리는 시간, 지도 앱 · 일정 수정
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.trip,
    required this.schedules,
    required this.schedule,
    required this.dayNo,
    required this.me,
    required this.onEdited,
  });

  final TripDetail trip;
  final List<Schedule> schedules;
  final Schedule schedule;
  final int dayNo;
  final LatLng? me;
  final VoidCallback onEdited;

  String get _status {
    if (schedule.status == ScheduleStatus.done) {
      return '완료';
    }
    if (schedule.status == ScheduleStatus.inProgress) {
      return '진행 중';
    }
    final next = schedules
        .where((s) => s.status == ScheduleStatus.planned)
        .firstOrNull;
    return next?.id == schedule.id && sameDay(schedule.day, DateTime.now())
        ? '다음 일정'
        : '예정';
  }

  @override
  Widget build(BuildContext context) {
    final number = schedules.indexOf(schedule) + 1;
    final me = this.me;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: schedule.isLocked
                    ? AppColors.ink
                    : AppColors.day(dayNo),
                child: schedule.isLocked
                    ? const Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: Colors.white,
                      )
                    : Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Text(
                Fmt.time(schedule.startTime),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  schedule.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        '${schedule.placeCategory?.label ?? schedule.placeText ?? ''} · ',
                  ),
                  TextSpan(
                    text: _status,
                    style: TextStyle(
                      color: _status == '다음 일정' || _status == '진행 중'
                          ? AppColors.primaryText
                          : AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          if (me != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FutureBuilder<TravelLeg>(
                future: services.places.travel(
                  fromLat: me.latitude,
                  fromLng: me.longitude,
                  toLat: schedule.placeLat!,
                  toLng: schedule.placeLng!,
                ),
                builder: (context, snap) => Row(
                  children: [
                    Icon(
                      snap.data?.icon ?? Icons.directions_walk,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      snap.hasData
                          ? '현재 위치에서 ${snap.data!.label}'
                          : snap.hasError
                          ? '이동 시간을 알 수 없어요'
                          : '이동 시간 계산 중…',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openInMapsApp(
                    context,
                    lat: schedule.placeLat!,
                    lng: schedule.placeLng!,
                    from: me,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('지도 앱 열기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final saved = await showScheduleForm(
                      context,
                      trip: trip,
                      day: schedule.day,
                      existing: schedule,
                    );
                    if (saved != null) {
                      onEdited();
                    }
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('일정 수정'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
