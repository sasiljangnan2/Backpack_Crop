import 'dart:convert';

import 'package:backpack/core/network/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('기존 main의 세션을 그대로 읽는다', () async {
    FlutterSecureStorage.setMockInitialValues({
      'backpack.session.v1': jsonEncode({
        'accessToken': 'main-access',
        'refreshToken': 'main-refresh',
      }),
    });
    final tokens = TokenStorage();
    await tokens.load();
    expect(tokens.accessToken, 'main-access');
    expect(tokens.refreshToken, 'main-refresh');
  });

  test('full-app의 분리된 세션을 한 쌍으로 옮기고 로그아웃하면 제거한다', () async {
    FlutterSecureStorage.setMockInitialValues({
      'backpack.accessToken': 'full-access',
      'backpack.refreshToken': 'full-refresh',
    });
    final tokens = TokenStorage();
    await tokens.load();
    expect(tokens.refreshToken, 'full-refresh');
    final stored = await const FlutterSecureStorage().readAll();
    expect(stored.keys, ['backpack.session.v1']);
    await tokens.clear();
    final restarted = TokenStorage();
    await restarted.load();
    expect(restarted.hasSession, isFalse);
  });
}
