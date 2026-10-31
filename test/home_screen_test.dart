import 'package:backpack/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home interactions and tabs work on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: TravelHomeScreen()));
    expect(find.text('구로몬 시장'), findsOneWidget);
    await tester.tap(find.byTooltip('알림'));
    await tester.pumpAndSettle();
    expect(find.text('알림'), findsWidgets);
    Navigator.of(tester.element(find.text('지출이 등록됐어요'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AI로 다시 짜기'));
    await tester.tap(find.text('AI로 다시 짜기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('추천 일정 적용'));
    await tester.tap(find.text('추천 일정 적용'));
    await tester.pumpAndSettle();
    expect(find.text('추천 일정을 적용했어요. 예약 시간에 맞춰 출발해요.'), findsOneWidget);
    await tester.ensureVisible(find.text('활동 기록'));
    await tester.tap(find.text('활동 기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('활동 완료로 기록'));
    await tester.pumpAndSettle();
    expect(find.text('기록 완료'), findsOneWidget);
    Future<void> tab(String label) async {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
    }

    await tab('일정');
    expect(find.byKey(const ValueKey('schedule-add')), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    await tab('경비');
    expect(find.text('여행 공동 지출'), findsOneWidget);
    await tab('준비');
    await tester.tap(find.byType(CheckboxListTile).at(2));
    await tester.pumpAndSettle();
    expect(find.text('여행 준비 3/4'), findsOneWidget);
    await tab('홈');
    expect(find.text('기록 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
