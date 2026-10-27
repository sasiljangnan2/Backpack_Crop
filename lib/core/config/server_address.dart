import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_config.dart';

/// 시험용 빌드(debug · profile)에서 앱 안에서 바꾸는 서버 주소.
///
/// PC에서 띄운 서버에 휴대폰으로 붙으면, Wi-Fi를 옮길 때마다 PC 주소가 바뀐다.
/// 그때 다시 빌드하지 않고 앱에서 주소만 고치게 한다.
/// 출시 빌드(release)는 빌드할 때 넣은 [AppConfig.apiBaseUrl]만 쓴다.
abstract final class ServerAddress {
  static const _key = 'backpack.serverUrl';
  static const _storage = FlutterSecureStorage();

  static bool get editable => !kReleaseMode;

  /// 저장해 둔 주소. 없거나 출시 빌드면 빌드할 때 넣은 주소
  static Future<String> load() async {
    if (!editable) {
      return AppConfig.apiBaseUrl;
    }
    try {
      return await _storage.read(key: _key) ?? AppConfig.apiBaseUrl;
    } catch (_) {
      return AppConfig.apiBaseUrl;
    }
  }

  /// 빌드할 때 넣은 주소와 같으면 저장해 둔 값을 지워, 다음 빌드의 주소를 따르게 한다
  static Future<void> save(String baseUrl) async {
    if (baseUrl == AppConfig.apiBaseUrl) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: baseUrl);
    }
  }

  /// `172.20.10.3`, `172.20.10.3:8080`, `http://172.20.10.3:8080/`을 모두
  /// `http://172.20.10.3:8080` 꼴로 맞춘다. 주소로 읽을 수 없으면 null.
  /// 앞에 http(s)://를 쓰지 않고 포트도 없으면 서버 기본 포트 8080을 붙인다.
  static String? normalize(String input) {
    var text = input.trim();
    if (text.isEmpty) {
      return null;
    }
    final hasScheme = text.contains('://');
    if (!hasScheme) {
      text = 'http://$text';
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    final port = uri.hasPort
        ? ':${uri.port}'
        : hasScheme
        ? ''
        : ':8080';
    return '${uri.scheme}://${uri.host}$port';
  }
}
