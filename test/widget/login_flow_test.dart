import 'dart:convert';

import 'package:backpack/app.dart';
import 'package:backpack/core/app_services.dart';
import 'package:backpack/core/network/api_client.dart';
import 'package:backpack/core/network/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

http.Response json(int status, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _user = {
  'id': 'u1',
  'email': 'host@backpack.dev',
  'name': '김방장',
  'notifySchedule': true,
  'notifyExpense': true,
  'notifySettlement': true,
};

/// 시연 1단계: 로그인 (오류 → 성공) → 빈 여행 목록
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
    FlutterSecureStorage.setMockInitialValues({});
    final api = ApiClient(
      tokens: TokenStorage(),
      baseUrl: 'http://test',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/auth/login':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['password'] != 'backpack1234') {
              return json(401, {
                'code': 'INVALID_CREDENTIALS',
                'message': '이메일 또는 비밀번호가 올바르지 않습니다.',
              });
            }
            return json(200, {
              'tokenType': 'Bearer',
              'accessToken': 'a',
              'accessTokenExpiresIn': 1800,
              'refreshToken': 'r',
              'user': _user,
            });
          case '/api/trips':
            return json(200, <Object>[]);
          case '/api/notifications/unread-count':
            return json(200, {'count': 0});
          default:
            return json(404, {'code': 'NOT_FOUND', 'message': '없음'});
        }
      }),
    );
    services = AppServices.withClient(api);
  });

  testWidgets('잘못된 비밀번호는 오류를 보여 주고, 맞으면 여행 목록으로 간다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BackpackApp());
    await services.auth.restore();
    await tester.pumpAndSettle();

    expect(find.text('일정부터 정산까지, 함께 가는 여행'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'host@backpack.dev');
    await tester.enterText(fields.at(1), 'wrong-pass1');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);

    await tester.enterText(fields.at(1), 'backpack1234');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('김방장님의 여행'), findsOneWidget);
    expect(find.text('아직 여행이 없어요'), findsOneWidget);
    expect(find.text('코드로 참여'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
