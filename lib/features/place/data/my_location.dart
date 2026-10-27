import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// 앱을 쓰는 동안의 내 위치. 위치가 꺼져 있거나 권한이 없으면 null을 돌려준다
/// (위치 없이도 일정 · 지도는 그대로 쓴다. NFR-02)
abstract final class MyLocation {
  /// [ask]가 false면 권한을 새로 묻지 않는다 (이미 허락한 경우에만 위치를 쓴다)
  static Future<LatLng?> current({bool ask = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      // 시간 안에 위치를 못 잡으면 마지막으로 알던 위치라도 쓴다
      try {
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : LatLng(last.latitude, last.longitude);
      } catch (_) {
        return null;
      }
    }
  }
}
