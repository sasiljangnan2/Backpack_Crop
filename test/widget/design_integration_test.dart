import 'dart:io';
import 'dart:ui' as ui;

import 'package:backpack/core/app_services.dart';
import 'package:backpack/core/network/api_client.dart';
import 'package:backpack/core/network/token_storage.dart';
import 'package:backpack/core/theme/app_colors.dart';
import 'package:backpack/core/theme/app_theme.dart';
import 'package:backpack/core/theme/app_typography.dart';
import 'package:backpack/features/expense/presentation/widgets/expense_summary_card.dart';
import 'package:backpack/features/trip/presentation/trip_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../support/full_app_fixture.dart';

final _boundary = GlobalKey();

class _LocationOff extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_INTEGRATION')) return;
  final oldShadows = debugDisableShadows;
  debugDisableShadows = false;
  try {
    (_boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary)
        .markNeedsPaint();
    await tester.pump();
    await tester.runAsync(() async {
      final repaint =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await repaint.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('.dart_tool/integration-captures')
          .create(recursive: true);
      await File('.dart_tool/integration-captures/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = oldShadows;
  }
}

Widget host(Widget child) => RepaintBoundary(
  key: _boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('ko', 'KR'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('ko', 'KR')],
    home: child,
  ),
);

void main() {
  final fixture = FullAppFixture();
  final location = GeolocatorPlatform.instance;
  tearDownAll(() => GeolocatorPlatform.instance = location);
  setUpAll(() async {
    GeolocatorPlatform.instance = _LocationOff();
    await initializeDateFormatting('ko_KR');
    FlutterSecureStorage.setMockInitialValues({});
    final tokens = TokenStorage();
    await tokens.save(
      access: 'integration-access',
      refresh: 'integration-refresh',
    );
    services = AppServices.withClient(
      ApiClient(
        tokens: tokens,
        baseUrl: 'http://test',
        client: MockClient(fixture.handle),
      ),
    );
    final fonts = FontLoader(AppTypography.fontFamily);
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      await (FontLoader('MaterialIcons')..addFont(
            File(
              '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });

  testWidgets('코랄 여행 화면에서 서버 경비·필터·정산·일정 추가가 연결된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(const TripShell(tripId: 't1')));
    await tester.pumpAndSettle();
    expect(find.text('오사카 4박 5일'), findsWidgets);
    await capture(tester, 'home');

    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('expense-screen-title'));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: title, matching: find.byType(RichText)),
    );
    expect(paragraph.text.style!.fontFamily, 'Pretendard');
    expect(paragraph.text.style!.fontSize, 20);
    expect(paragraph.text.style!.fontWeight, FontWeight.w800);
    expect(
      Theme.of(tester.element(title)).colorScheme.primary,
      const Color(0xFFD0442B),
    );
    final summary = find.byType(ExpenseSummaryCard);
    expect(
      find.descendant(of: summary, matching: find.text('₩162,316')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('₩33,005')),
      findsOneWidget,
    );
    final settlementLabel = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text('정산 미리보기'),
        matching: find.byType(RichText),
      ),
    );
    expect(settlementLabel.text.style!.fontFamily, 'Pretendard');
    await capture(tester, 'expenses');
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '식비'));
    await tester.tap(find.widgetWithText(ChoiceChip, '식비'));
    await tester.pumpAndSettle();
    expect(
      fixture.requests.any((r) => r.url.queryParameters['category'] == 'FOOD'),
      isTrue,
    );
    expect(
      find.descendant(of: summary, matching: find.text('₩162,316')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('이치란 라멘 난바점'));
    expect(find.text('우메다 스카이빌딩 입장권'), findsNothing);

    await tester.ensureVisible(find.text('정산 미리보기'));
    await tester.tap(find.text('정산 미리보기'));
    await tester.pumpAndSettle();
    expect(find.text('정산 결과 공유'), findsOneWidget);
    await capture(tester, 'settlement');

    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await capture(tester, 'schedule');
    await tester.tap(find.widgetWithText(FloatingActionButton, '일정 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '도톤보리 산책');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '추가'));
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();
    expect(fixture.schedules.last['title'], '도톤보리 산책');
    expect(
      fixture.requests.where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/schedules'),
      ),
      hasLength(1),
    );
    await tester.ensureVisible(find.text('AI로 다시 짜기'));
    await tester.tap(find.text('AI로 다시 짜기'));
    await tester.pumpAndSettle();
    await capture(tester, 'ai-replan');
    await tester.tap(find.text('추천 3안 받기'));
    await tester.pumpAndSettle();
    expect(find.text('추천안 비교'), findsOneWidget);
    await capture(tester, 'ai-compare');
    await tester.tap(find.text('이 안으로 적용'));
    await tester.pumpAndSettle();
    expect(fixture.schedules.first['title'], '난바 카페에서 휴식');
    expect(
      fixture.requests.where((r) => r.url.path.endsWith('/replan/apply')),
      hasLength(1),
    );
    expect(
      fixture.requests.every(
        (r) => r.headers['Authorization'] == 'Bearer integration-access',
      ),
      isTrue,
    );
    expect(fixture.unexpected, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면과 큰 글자에서도 경비 숫자가 보존된다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: ExpenseSummaryCard(
                  totalKrw: 1234567890,
                  budgetKrw: 2000000000,
                  myShareKrw: 1234567890,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('₩1,234,567,890'), findsNWidgets(2));
    expect(AppColors.primary, const Color(0xFFD0442B));
    expect(tester.takeException(), isNull);
  });
}
