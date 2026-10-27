import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../schedule/data/schedule_models.dart';
import 'google_schedule_map.dart';

/// 지도를 옮기는 손잡이. 구글 지도 · OpenStreetMap 어느 쪽이든 같은 방법으로 쓴다
class ScheduleMapController {
  void Function(LatLng point, double? zoom)? _mover;

  /// 지도가 만들어질 때 지도 쪽에서 붙인다
  void attach(void Function(LatLng point, double? zoom) mover) =>
      _mover = mover;

  /// [zoom]이 없으면 지금 확대 정도를 지킨다
  void moveTo(LatLng point, {double? zoom}) => _mover?.call(point, zoom);
}

/// 그날 일정 지도 (BP-SC-001 ① 미리보기, BP-SC-004 크게 보기).
/// 번호 핀은 일정 목록의 번호와 같고, 핀을 순서대로 점선으로 잇는다.
/// 고정 = 검정 자물쇠, 완료 = 회색, 선택 = 주요 색 테두리, 파란 점 = 내 위치.
///
/// 앱을 GOOGLE_MAPS_API_KEY와 함께 빌드하면 구글 지도, 아니면 OpenStreetMap(무료, 키 없음)으로 그린다.
/// OpenStreetMap 타일을 못 받으면 [onTilesFailed]를 부른다
class ScheduleMapView extends StatelessWidget {
  const ScheduleMapView({
    super.key,
    required this.schedules,
    required this.dayNo,
    this.selectedId,
    this.onSelect,
    this.myLocation,
    this.controller,
    this.interactive = true,
    this.fitPadding = const EdgeInsets.all(36),
    this.onTilesFailed,
  });

  /// 그날 일정 전체 (시간순). 좌표가 있는 일정만 핀으로 그린다
  final List<Schedule> schedules;
  final int dayNo;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final LatLng? myLocation;
  final ScheduleMapController? controller;
  final bool interactive;
  final EdgeInsets fitPadding;
  final VoidCallback? onTilesFailed;

  static LatLng pointOf(Schedule s) => LatLng(s.placeLat!, s.placeLng!);

  @override
  Widget build(BuildContext context) {
    if (AppConfig.useGoogleMaps) {
      return GoogleScheduleMap(
        schedules: schedules,
        dayNo: dayNo,
        selectedId: selectedId,
        onSelect: onSelect,
        myLocation: myLocation,
        controller: controller,
        interactive: interactive,
        fitPadding: fitPadding,
      );
    }
    return _OsmScheduleMap(view: this);
  }
}

class _OsmScheduleMap extends StatefulWidget {
  const _OsmScheduleMap({required this.view});

  final ScheduleMapView view;

  @override
  State<_OsmScheduleMap> createState() => _OsmScheduleMapState();
}

class _OsmScheduleMapState extends State<_OsmScheduleMap> {
  final _map = MapController();
  bool _reportedFailure = false;

  ScheduleMapView get view => widget.view;

  @override
  void initState() {
    super.initState();
    widget.view.controller?.attach(
      (point, zoom) => _map.move(point, zoom ?? math.max(15, _map.camera.zoom)),
    );
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placed = [
      for (var i = 0; i < view.schedules.length; i++)
        if (view.schedules[i].hasPlace)
          (index: i + 1, schedule: view.schedules[i]),
    ];
    final points = [
      for (final p in placed) ScheduleMapView.pointOf(p.schedule),
    ];
    final fitTo = [...points, ?view.myLocation];
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCameraFit: fitTo.length >= 2
            ? CameraFit.coordinates(
                coordinates: fitTo,
                padding: view.fitPadding,
                maxZoom: 16,
              )
            : null,
        initialCenter: fitTo.isEmpty
            ? const LatLng(37.5665, 126.9780)
            : fitTo.first,
        initialZoom: 15,
        interactionOptions: InteractionOptions(
          flags: view.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onTap: view.interactive && view.onSelect != null
            ? (_, _) => view.onSelect!('')
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // 공용 타일 서버 사용 정책: 어떤 앱인지 알린다
          userAgentPackageName: 'com.backpackcorp.backpack',
          errorTileCallback: (tile, error, stack) {
            if (!_reportedFailure) {
              _reportedFailure = true;
              view.onTilesFailed?.call();
            }
          },
        ),
        if (points.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: AppColors.day(view.dayNo),
                strokeWidth: 3,
                pattern: StrokePattern.dashed(segments: const [10, 7]),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final p in placed)
              Marker(
                point: ScheduleMapView.pointOf(p.schedule),
                width: 40,
                height: 40,
                child: _Pin(
                  number: p.index,
                  schedule: p.schedule,
                  dayNo: view.dayNo,
                  selected: p.schedule.id == view.selectedId,
                  onTap: view.onSelect == null
                      ? null
                      : () => view.onSelect!(p.schedule.id),
                ),
              ),
            if (view.myLocation != null)
              Marker(
                point: view.myLocation!,
                width: 22,
                height: 22,
                child: const _MyDot(),
              ),
          ],
        ),
        SimpleAttributionWidget(
          source: const Text('OpenStreetMap', style: TextStyle(fontSize: 10)),
          onTap: () => launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.number,
    required this.schedule,
    required this.dayNo,
    required this.selected,
    this.onTap,
  });

  final int number;
  final Schedule schedule;
  final int dayNo;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = schedule.status == ScheduleStatus.done;
    final color = schedule.isLocked
        ? AppColors.ink
        : done
        ? AppColors.disabled
        : AppColors.day(dayNo);
    final size = selected ? 34.0 : 28.0;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.primary : Colors.white,
              width: selected ? 3 : 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: schedule.isLocked
              ? const Icon(Icons.lock_outline, size: 14, color: Colors.white)
              : Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class _MyDot extends StatelessWidget {
  const _MyDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D83F5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x552D83F5), blurRadius: 8)],
      ),
    );
  }
}

/// 길 안내는 외부 지도 앱으로 (앱 안 실시간 내비게이션은 범위 밖). 구글 지도 앱 · 웹이 대중교통 경로를 보여 준다
Future<void> openInMapsApp(
  BuildContext context, {
  required double lat,
  required double lng,
  LatLng? from,
}) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$lat,$lng',
    if (from != null) 'origin': '${from.latitude},${from.longitude}',
    'travelmode': 'transit',
  });
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('지도 앱을 열지 못했어요.')));
  }
}
