import 'dart:convert';

import 'package:backpack/core/app_services.dart';
import 'package:backpack/core/network/api_client.dart';
import 'package:backpack/core/network/token_storage.dart';
import 'package:backpack/core/theme/app_theme.dart';
import 'package:backpack/features/trip/presentation/trip_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/full_app_fixture.dart';

class _FundFixture extends FullAppFixture {
  static const third = {'memberId': 'm3', 'name': '재윤'};
  final recorded = <Map<String, Object?>>[];
  int firstPaid = 1000;

  Map<String, Object?> get fund => {
    'collectedKrw': firstPaid,
    'spentKrw': 0,
    'remainingKrw': firstPaid,
    'members': [
      {'member': FullAppFixture.me, 'contributedKrw': firstPaid},
      {'member': FullAppFixture.other, 'contributedKrw': 0},
      {'member': third, 'contributedKrw': 0},
    ],
    'contributions': [],
  };

  @override
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (path == '/api/trips/t1') {
      return reply({
        ...FullAppFixture.trip,
        'members': [
          ...FullAppFixture.trip['members'] as List<Object>,
          {...third, 'role': 'MEMBER', 'isMe': false},
        ],
      });
    }
    if (path.endsWith('/budget-items')) {
      return reply({
        ...FullAppFixture.budget,
        'totalBudgetKrw': 10001,
        'memberCount': 3,
        'fund': fund,
      });
    }
    if (request.method == 'POST' &&
        path == '/api/trips/t1/fund/contributions') {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      recorded.add(body);
      firstPaid += body['amountKrw'] as int;
      return reply(fund, 201);
    }
    return super.handle(request);
  }
}

void main() {
  testWidgets('경비에서 공금을 나누고 실제 납부만 반영한다', (tester) async {
    final fixture = _FundFixture();
    FlutterSecureStorage.setMockInitialValues({});
    services = AppServices.withClient(
      ApiClient(
        tokens: TokenStorage(),
        baseUrl: 'http://test',
        client: MockClient(fixture.handle),
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const TripShell(tripId: 't1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('예산'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('공금 N분의 1'));
    await tester.tap(find.text('공금 N분의 1'));
    await tester.pumpAndSettle();

    expect(find.text('₩3,334'), findsNWidgets(2));
    expect(find.text('₩3,333'), findsOneWidget);
    expect(find.text('남은 납부 ₩2,334'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '재윤'));
    await tester.pumpAndSettle();
    expect(find.text('₩5,001'), findsOneWidget);
    expect(find.text('₩5,000'), findsOneWidget);
    expect(fixture.recorded, isEmpty);
    await tester.tap(find.widgetWithText(FilterChip, '재윤'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('납부 등록').first);
    await tester.pumpAndSettle();
    expect(find.text('2334'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('fund-contribution-amount')),
      '2000',
    );
    await tester.ensureVisible(find.text('납부 저장'));
    await tester.tap(find.text('납부 저장'));
    await tester.pumpAndSettle();
    expect(fixture.recorded, [
      {'memberId': 'm1', 'amountKrw': 2000, 'memo': null},
    ]);
    expect(find.text('납부 ₩3,000'), findsOneWidget);
    expect(find.text('남은 납부 ₩334'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('₩3,000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
