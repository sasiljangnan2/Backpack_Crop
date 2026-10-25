import 'package:backpack/features/expense/data/expense_split_repository.dart';
import 'package:backpack/features/expense/data/sample_expense_split_repository.dart';
import 'package:backpack/features/expense/presentation/expense_split_controller.dart';
import 'package:backpack/features/expense/presentation/expense_split_preview.dart';
import 'package:backpack/features/expense/presentation/expense_split_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Storyboard shares and total stay unchanged', () async {
    final controller = ExpenseSplitController(
      const SampleExpenseSplitRepository(),
    );
    addTearDown(controller.dispose);
    await controller.load();
    final result = controller.preview!;
    expect(result.totalLocal, 7360);
    expect(result.totalWon, 68816);
    expect(result.amountsWon, [14305, 14913, 14306, 14306, 10986]);
    expect(result.adjustments, [-1, 0, 0, 0, 0]);
  });

  test(
    'Rounding conserves money across subsets, payers and member order',
    () async {
      final data = await const SampleExpenseSplitRepository().loadSplitData();
      for (var mask = 1; mask < 32; mask++) {
        final selected = {
          for (var i = 0; i < data.members.length; i++)
            if (mask & (1 << i) != 0) data.members[i].memberId,
        };
        final items = [
          ExpenseSplitItem(
            name: '라멘',
            quantity: 1,
            amountLocal: 980,
            memberIds: selected,
          ),
          ExpenseSplitItem(
            name: '추가 메뉴',
            quantity: 1,
            amountLocal: 103,
            memberIds: selected,
          ),
        ];
        for (final payer in data.members) {
          for (final members in [
            data.members,
            data.members.reversed.toList(),
          ]) {
            final result = calculateSplitPreview(
              items,
              members: members,
              payerMemberId: payer.memberId,
              rate: data.previewRate,
            )!;
            expect(
              result.amountsWon.fold<int>(0, (sum, value) => sum + value),
              result.totalWon,
            );
            expect(result.amountsWon.every((value) => value >= 0), isTrue);
          }
        }
      }
      final empty = [data.items.first.withMembers({})];
      expect(
        calculateSplitPreview(
          empty,
          members: data.members,
          payerMemberId: data.payerMemberId,
          rate: data.previewRate,
        ),
        isNull,
      );
      expect(
        calculateSplitPreview(
          empty,
          members: data.members,
          payerMemberId: data.payerMemberId,
          rate: data.previewRate,
          isEqual: true,
        ),
        isNotNull,
      );
    },
  );

  testWidgets(
    'Participant selection, mode switching and empty selection work on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ExpenseSplitScreen()));
      await tester.pumpAndSettle();
      final share = find.byKey(const ValueKey('payer-share'));
      String currentShare() => tester.widget<Text>(share).data!;
      final firstShare = currentShare();
      final lastPerson = find.byKey(const ValueKey('item-0-person-4'));
      await Scrollable.ensureVisible(tester.element(lastPerson), alignment: .4);
      await tester.pumpAndSettle();
      await tester.tap(lastPerson);
      await tester.pumpAndSettle();
      final changedShare = currentShare();
      expect(changedShare, isNot(firstShare));
      await tester.scrollUntilVisible(
        find.text('균등 분담'),
        -160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('균등 분담'));
      await tester.pumpAndSettle();
      expect(currentShare(), isNot(changedShare));
      await tester.tap(find.text('항목별 분담'));
      await tester.pumpAndSettle();
      expect(currentShare(), changedShare);
      for (var person = 0; person < 4; person++) {
        final chip = find.byKey(ValueKey('item-0-person-$person'));
        await Scrollable.ensureVisible(tester.element(chip), alignment: .4);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pump();
      }
      final button = find.widgetWithText(FilledButton, '분담 결과 확인');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('참여자를 선택하지 않은 항목이 1개 있어요.'), findsOneWidget);
      final firstPerson = find.byKey(const ValueKey('item-0-person-0'));
      await Scrollable.ensureVisible(
        tester.element(firstPerson),
        alignment: .4,
      );
      await tester.pumpAndSettle();
      await tester.tap(firstPerson);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('개인별 부담'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('부담액 합계'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('부담액 합계'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
