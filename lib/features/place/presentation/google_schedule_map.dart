import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../schedule/data/schedule_models.dart';
import 'schedule_map.dart';

/// [ScheduleMapView]의 구글 지도판. 앱을 GOOGLE_MAPS_API_KEY와 함께 빌드했을 때 쓴다.
/// 번호 핀은 그림으로 그려 넣고(일차 색 · 완료 회색 · 고정 자물쇠 · 선택 테두리), 핀을 점선으로 잇는다.
/// 작은 미리보기([interactive] = false)는 가벼운 정지 지도(lite mode)로 그린다
class GoogleScheduleMap extends StatefulWidget {
  const GoogleScheduleMap({
    super.key,
    required this.schedules,
    required this.dayNo,
    this.selectedId,
    this.onSelect,
    this.myLocation,
    this.controller,
    this.interactive = true,
    this.fitPadding = const EdgeInsets.all(36),
  });

  final List<Schedule> schedules;
  final int dayNo;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final LatLng? myLocation;
  final ScheduleMapController? controller;
  final bool interactive;
  final EdgeInsets fitPadding;

  @override
  State<GoogleScheduleMap> createState() => _GoogleScheduleMapState();
}

class _GoogleScheduleMapState extends State<GoogleScheduleMap> {
  gm.GoogleMapController? _map;
  final Map<String, gm.BitmapDescriptor> _icons = {};
  double _ratio = 2;

  @override
  void initState() {
    super.initState();
    widget.controller?.attach((point, zoom) {
      final target = gm.LatLng(point.latitude, point.longitude);
      _map?.animateCamera(
        zoom == null
            ? gm.CameraUpdate.newLatLng(target)
            : gm.CameraUpdate.newLatLngZoom(target, zoom),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ratio = MediaQuery.devicePixelRatioOf(context);
    _prepareIcons();
  }

  @override
  void didUpdateWidget(covariant GoogleScheduleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareIcons();
  }

  List<({int number, Schedule schedule})> get _placed => [
    for (var i = 0; i < widget.schedules.length; i++)
      if (widget.schedules[i].hasPlace)
        (number: i + 1, schedule: widget.schedules[i]),
  ];

  String _keyOf(int number, Schedule s) {
    final selected = s.id == widget.selectedId;
    return '${_colorOf(s).toARGB32()}|${s.isLocked ? 'lock' : number}|$selected';
  }

  Color _colorOf(Schedule s) => s.isLocked
      ? AppColors.ink
      : s.status == ScheduleStatus.done
      ? AppColors.disabled
      : AppColors.day(widget.dayNo);

  // 핀 그림은 한 번 그려 두고 다시 쓴다
  Future<void> _prepareIcons() async {
    var added = false;
    for (final p in _placed) {
      final key = _keyOf(p.number, p.schedule);
      if (_icons.containsKey(key)) {
        continue;
      }
      _icons[key] = await _pin(
        color: _colorOf(p.schedule),
        text: p.schedule.isLocked ? null : '${p.number}',
        selected: p.schedule.id == widget.selectedId,
        ratio: _ratio,
      );
      added = true;
    }
    if (widget.myLocation != null && !_icons.containsKey('me')) {
      _icons['me'] = await _myDot(_ratio);
      added = true;
    }
    if (added && mounted) {
      setState(() {});
    }
  }

  Future<void> _fit() async {
    final map = _map;
    final points = [
      for (final p in _placed) ScheduleMapView.pointOf(p.schedule),
      ?widget.myLocation,
    ];
    if (map == null || points.isEmpty) {
      return;
    }
    // 지도 크기가 정해진 뒤에 맞춘다 (바로 맞추면 크기가 0이라 실패한다)
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      if (points.length == 1) {
        await map.moveCamera(
          gm.CameraUpdate.newLatLngZoom(
            gm.LatLng(points.first.latitude, points.first.longitude),
            15,
          ),
        );
        return;
      }
      final lats = points.map((p) => p.latitude);
      final lngs = points.map((p) => p.longitude);
      await map.moveCamera(
        gm.CameraUpdate.newLatLngBounds(
          gm.LatLngBounds(
            southwest: gm.LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
            northeast: gm.LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
          ),
          widget.fitPadding.top,
        ),
      );
    } catch (_) {
      // 지도가 아직 준비되지 않았으면 처음 위치 그대로 둔다
    }
  }

  @override
  Widget build(BuildContext context) {
    final placed = _placed;
    final first = placed.isNotEmpty
        ? ScheduleMapView.pointOf(placed.first.schedule)
        : (widget.myLocation ?? const LatLng(37.5665, 126.9780));
    final points = [
      for (final p in placed)
        gm.LatLng(p.schedule.placeLat!, p.schedule.placeLng!),
    ];
    final markers = <gm.Marker>{
      for (final p in placed)
        if (_icons[_keyOf(p.number, p.schedule)] case final icon?)
          gm.Marker(
            markerId: gm.MarkerId(p.schedule.id),
            position: gm.LatLng(p.schedule.placeLat!, p.schedule.placeLng!),
            icon: icon,
            anchor: const Offset(.5, .5),
            zIndexInt: p.schedule.id == widget.selectedId ? 2 : 1,
            consumeTapEvents: true,
            onTap: widget.onSelect == null
                ? null
                : () => widget.onSelect!(p.schedule.id),
          ),
      if (widget.myLocation case final me?)
        if (_icons['me'] case final icon?)
          gm.Marker(
            markerId: const gm.MarkerId('me'),
            position: gm.LatLng(me.latitude, me.longitude),
            icon: icon,
            anchor: const Offset(.5, .5),
          ),
    };
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(first.latitude, first.longitude),
        zoom: 14,
      ),
      markers: markers,
      polylines: {
        if (points.length >= 2)
          gm.Polyline(
            polylineId: const gm.PolylineId('route'),
            points: points,
            color: AppColors.day(widget.dayNo),
            width: 4,
            patterns: [gm.PatternItem.dash(24), gm.PatternItem.gap(14)],
          ),
      },
      // 아래쪽 패널에 가리지 않게 지도의 쓸 수 있는 영역을 줄인다
      padding: EdgeInsets.only(
        bottom: math.max(0, widget.fitPadding.bottom - widget.fitPadding.top),
      ),
      liteModeEnabled: !widget.interactive,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      onMapCreated: (controller) {
        _map = controller;
        _fit();
      },
      onTap: widget.interactive && widget.onSelect != null
          ? (_) => widget.onSelect!('')
          : null,
    );
  }
}

// 번호 핀: 흰 테두리(선택하면 주요 색) 동그라미 안에 번호 또는 자물쇠
Future<gm.BitmapDescriptor> _pin({
  required Color color,
  required String? text,
  required bool selected,
  required double ratio,
}) async {
  final size = (selected ? 34.0 : 28.0) * ratio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);
  canvas.drawCircle(
    center.translate(0, ratio),
    size / 2 - ratio,
    Paint()..color = const Color(0x33000000),
  );
  canvas.drawCircle(
    center,
    size / 2 - ratio,
    Paint()..color = selected ? AppColors.primary : Colors.white,
  );
  canvas.drawCircle(
    center,
    size / 2 - ratio - (selected ? 3 : 2) * ratio,
    Paint()..color = color,
  );
  final lock = text == null;
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: lock ? String.fromCharCode(Icons.lock_outline.codePoint) : text,
      style: TextStyle(
        color: Colors.white,
        fontSize: (lock ? 14 : 12) * ratio,
        fontWeight: FontWeight.w800,
        fontFamily: lock ? Icons.lock_outline.fontFamily : null,
        package: lock ? Icons.lock_outline.fontPackage : null,
      ),
    ),
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  return _toBitmap(recorder, size, ratio);
}

// 내 위치: 흰 테두리의 파란 점
Future<gm.BitmapDescriptor> _myDot(double ratio) async {
  final size = 22 * ratio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);
  canvas.drawCircle(center, size / 2, Paint()..color = const Color(0x552D83F5));
  canvas.drawCircle(
    center,
    size / 2 - 3 * ratio,
    Paint()..color = Colors.white,
  );
  canvas.drawCircle(
    center,
    size / 2 - 6 * ratio,
    Paint()..color = const Color(0xFF2D83F5),
  );
  return _toBitmap(recorder, size, ratio);
}

Future<gm.BitmapDescriptor> _toBitmap(
  ui.PictureRecorder recorder,
  double size,
  double ratio,
) async {
  final image = await recorder.endRecording().toImage(size.ceil(), size.ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return gm.BitmapDescriptor.bytes(
    data!.buffer.asUint8List(),
    imagePixelRatio: ratio,
  );
}
