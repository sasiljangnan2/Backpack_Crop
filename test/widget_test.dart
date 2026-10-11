import 'package:backpack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Welcome actions stay accessible on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    expect(find.text('Backpack'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final guestAction = find.text('초대 코드로 게스트 참여');
    await tester.ensureVisible(guestAction);
    await tester.tap(guestAction);
    await tester.pump();
    expect(find.text('초대 코드로 게스트 참여 기능은 준비 중이에요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
