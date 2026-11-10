import 'package:backpack/core/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(void Function(BuildContext) onSheetButton) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (sheet) => TextButton(
              onPressed: () => onSheetButton(sheet),
              child: const Text('시트 버튼'),
            ),
          ),
          child: const Text('시트 열기'),
        ),
      ),
    ),
  );

  testWidgets('시트 안에서 띄운 안내는 시트 위에 보이고 잠시 뒤 사라진다', (tester) async {
    await tester.pumpWidget(app((sheet) => showSnack(sheet, '복사했어요.')));
    await tester.tap(find.text('시트 열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('시트 버튼'));
    await tester.pump();

    // Scaffold 스낵바가 아니라 오버레이에 떠서, 시트가 열린 채로 보인다
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('복사했어요.'), findsOneWidget);
    expect(find.text('시트 버튼'), findsOneWidget);
    // 스낵바처럼 화면 낭독기가 바로 읽는다
    expect(
      find.ancestor(
        of: find.text('복사했어요.'),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    // 안내가 시트 버튼을 가리지 않는다 (눌림이 아래로 지나간다)
    await tester.tap(find.text('시트 버튼'));
    await tester.pump();
    expect(find.text('복사했어요.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('복사했어요.'), findsNothing);
  });

  testWidgets('시트 밖에서는 평소처럼 스낵바로 띄운다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSnack(context, '저장했어요.'),
              child: const Text('저장'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(find.widgetWithText(SnackBar, '저장했어요.'), findsOneWidget);
  });
}
