import 'package:backpack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Signup validates input and requires consent on a compact screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.ensureVisible(find.text('회원가입'));
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(4));
      await tester.enterText(fields.at(0), '여행자');
      await tester.enterText(fields.at(1), 'invalid');
      await tester.pump();
      expect(find.text('올바른 이메일 주소를 입력해 주세요.'), findsOneWidget);
      await tester.enterText(fields.at(1), 'traveler@example.com');
      await tester.enterText(fields.at(2), 'backpack123');
      await tester.enterText(fields.at(3), 'different');
      await tester.pump();
      expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
      await tester.enterText(fields.at(3), 'backpack123');
      await tester.pump();
      FilledButton button() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '가입하고 시작하기'),
      );
      expect(button().onPressed, isNull);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(button().onPressed, isNotNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.widgetWithText(FilledButton, '가입하고 시작하기')).bottom,
        lessThanOrEqualTo(368),
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('약관 전문 보기'));
      await tester.tap(find.byTooltip('약관 전문 보기'));
      await tester.pumpAndSettle();
      expect(find.text('약관 전문'), findsOneWidget);
      await tester.tap(find.text('개인정보 수집·이용'));
      await tester.pumpAndSettle();
      expect(find.text('회원 가입'), findsOneWidget);
      await tester.tap(find.text('동의하고 닫기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
