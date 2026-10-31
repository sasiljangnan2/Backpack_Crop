import 'package:backpack/app.dart';
import 'package:backpack/core/app_dependencies.dart';
import 'package:backpack/core/theme/app_theme.dart';
import 'package:backpack/core/theme/app_typography.dart';
import 'package:backpack/features/expense/presentation/widgets/expense_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_trip_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader(AppTypography.fontFamily);
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$name.otf'));
    }
    await loader.load();
  });
  void compact(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Expense amounts inherit the bundled font through the real sample-home path',
    (tester) async {
      compact(tester);
      final fixture = AuthTripFixture();
      final deps = AppDependencies.create(
        store: MemorySessionStore(),
        client: fixture.client(),
        baseUrl: 'http://fixture',
      );
      addTearDown(deps.dispose);
      await tester.pumpWidget(MyApp(dependencies: deps));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('샘플 여행 홈 둘러보기'));
      await tester.tap(find.text('샘플 여행 홈 둘러보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, '경비'));
      await tester.pumpAndSettle();
      for (final key in ['expense-total', 'expense-my-share']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byKey(ValueKey(key)),
        );
        expect(paragraph.text.style!.fontFamily, AppTypography.fontFamily);
        expect(paragraph.text.style!.fontWeight, FontWeight.w700);
        expect(
          paragraph.text.style!.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('expense-total'))).data,
        '₩162,316',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Large font amounts wrap without hiding the currency or overflowing the summary',
    (tester) async {
      compact(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.8),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: ExpenseSummaryCard(
                    totalKrw: 1234567890,
                    myShareKrw: 1234567890,
                    budgetKrw: 2000000000,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('expense-my-share')))
            .data,
        '₩1,234,567,890',
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('expense-my-share'))).right,
        lessThanOrEqualTo(300),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
