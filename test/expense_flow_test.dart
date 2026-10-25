import 'package:backpack/features/expense/data/expense_repository.dart';
import 'package:backpack/features/expense/data/expense_request.dart';
import 'package:backpack/features/expense/data/expense_split_repository.dart';
import 'package:backpack/features/expense/data/memory_expense_repository.dart';
import 'package:backpack/features/expense/presentation/expense_list_controller.dart';
import 'package:backpack/features/expense/presentation/expense_list_screen.dart';
import 'package:backpack/features/expense/presentation/expense_split_controller.dart';
import 'package:backpack/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements ExpenseRepository {
  _Repository(this.delegate);
  final ExpenseRepository delegate;
  bool hasLoadError = false;
  bool hasSaveError = false;
  bool isEmpty = false;
  @override
  Future<ExpenseOverview> loadExpenses() async {
    if (hasLoadError) {
      throw StateError('load failure');
    }
    final loaded = await delegate.loadExpenses();
    return ExpenseOverview(
      trip: loaded.trip,
      expenses: isEmpty ? [] : loaded.expenses,
    );
  }

  @override
  Future<ExpenseRecord> saveExpense(ExpenseRecord expense) {
    if (hasSaveError) {
      return Future.error(StateError('save failure'));
    }
    return delegate.saveExpense(expense);
  }
}

void compact(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 160,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String title, String amount) async {
  await tester.enterText(find.byKey(const ValueKey('expense-title')), title);
  await reveal(tester, find.byKey(const ValueKey('item-name-0')));
  await tester.enterText(find.byKey(const ValueKey('item-name-0')), '택시');
  await reveal(tester, find.byKey(const ValueKey('item-amount-0')));
  await tester.enterText(find.byKey(const ValueKey('item-amount-0')), amount);
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('expense-next')));
  await tester.pumpAndSettle();
}

Future<void> apply(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '분담 결과 확인'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('apply-split')));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'KRW request omits foreign fields; large preview amounts do not overflow',
    () async {
      final overview = await MemoryExpenseRepository().loadExpenses();
      final trip = overview.trip;
      for (final currency in ['KRW', 'JPY']) {
        final data = ExpenseSplitData(
          tripName: trip.tripName,
          title: '큰 금액',
          paidDate: '2026-11-01',
          payerMemberId: trip.currentMemberId,
          previewRate: currency == 'KRW' ? 1 : 1000000,
          currencyCode: currency,
          initialSplitMethod: SplitMethod.equal,
          members: trip.members,
          items: [
            for (var i = 0; i < 20; i++)
              ExpenseSplitItem(
                name: '항목 $i',
                quantity: 1,
                amountLocal: 100000000,
                memberIds: trip.members
                    .map((member) => member.memberId)
                    .toSet(),
              ),
          ],
        );
        final controller = ExpenseSplitController(
          DraftExpenseSplitRepository(data),
        );
        await controller.load();
        final request = controller.createRequest()!;
        expect(
          controller.preview!.totalWon,
          currency == 'KRW' ? 2000000000 : 2000000000000000,
        );
        expect(
          controller.preview!.amountsWon.fold<int>(
            0,
            (sum, value) => sum + value,
          ),
          controller.preview!.totalWon,
        );
        if (currency == 'KRW') {
          expect(request.rateMode, RateMode.krw);
          expect(request.amountLocal, isNull);
          expect(request.manualRate, isNull);
          expect(request.amountKrw, 2000000000);
          expect(request.items.single.amountLocal, isNull);
          expect(request.items.single.amountKrw, 2000000000);
        }
        controller.dispose();
      }
    },
  );

  test(
    'Failed save preserves the list, retry updates totals without a duplicate',
    () async {
      final repository = _Repository(MemoryExpenseRepository());
      final list = ExpenseListController(repository);
      addTearDown(list.dispose);
      await list.load();
      final record = list.expenses.first;
      final split = ExpenseSplitController(
        DraftExpenseSplitRepository(record.data),
      );
      addTearDown(split.dispose);
      await split.load();
      final selection = split.createSelection()!;
      repository.hasSaveError = true;
      await expectLater(list.save(selection, id: record.id), throwsStateError);
      expect(list.expenses, hasLength(2));
      expect(list.totalKrw, 162316);
      repository.hasSaveError = false;
      await list.save(selection, id: record.id);
      expect(list.expenses, hasLength(2));
      expect(list.totalKrw, 162316);
      list.filter(ExpenseCategory.shopping);
      expect(list.expenses, isEmpty);
      await list.save(selection);
      expect(list.category, isNull);
      expect(list.expenses, hasLength(3));
    },
  );

  testWidgets(
    'Create, choose participants, view and edit one expense on a small phone',
    (tester) async {
      compact(tester);
      final repository = MemoryExpenseRepository();
      await tester.pumpWidget(
        MaterialApp(home: ExpenseListScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('expense-add')));
      await tester.pumpAndSettle();
      await fill(tester, '공항 이동', '1000');
      await next(tester);
      await tester.tap(find.text('항목별 분담'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('item-0-person-4')));
      await tester.tap(find.byKey(const ValueKey('item-0-person-4')));
      await tester.pumpAndSettle();
      await apply(tester);
      expect(find.text('지출 추가'), findsOneWidget);
      final loaded = await repository.loadExpenses();
      expect(loaded.expenses, hasLength(3));
      final saved = loaded.expenses.last;
      expect(saved.request.title, '공항 이동');
      expect(saved.amountKrw, 9350);
      expect(saved.request.items.single.members, hasLength(4));
      expect(saved.sharesKrw[loaded.trip.members.last.memberId], 0);
      await reveal(tester, find.text('공항 이동'));
      await tester.tap(find.text('공항 이동'));
      await tester.pumpAndSettle();
      expect(find.text('지출 상세'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('expense-edit')));
      await tester.pumpAndSettle();
      await fill(tester, '공항 택시 수정', '2000');
      await next(tester);
      await reveal(tester, find.byKey(const ValueKey('item-0-person-4')));
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('item-0-person-4')))
            .selected,
        isFalse,
      );
      await apply(tester);
      expect(find.text('공항 택시 수정'), findsOneWidget);
      final updated = await repository.loadExpenses();
      expect(updated.expenses, hasLength(3));
      expect(updated.expenses.last.id, saved.id);
      expect(updated.expenses.last.amountKrw, 18700);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('expense-total')),
        delta: -160,
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('expense-total'))).data,
        '₩181,016',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Form rejects missing fields and fractional won; cancellation does not save',
    (tester) async {
      compact(tester);
      final repository = MemoryExpenseRepository();
      await tester.pumpWidget(
        MaterialApp(home: ExpenseListScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('expense-add')));
      await tester.pumpAndSettle();
      await next(tester);
      expect(find.text('지출명을 입력해 주세요.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('expense-title')),
        '원화 택시',
      );
      await reveal(tester, find.byKey(const ValueKey('expense-currency')));
      await tester.tap(find.byKey(const ValueKey('expense-currency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('한국 원 (KRW)').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('item-name-0')));
      await tester.enterText(find.byKey(const ValueKey('item-name-0')), '택시');
      await reveal(tester, find.byKey(const ValueKey('item-amount-0')));
      await tester.enterText(
        find.byKey(const ValueKey('item-amount-0')),
        '1000.5',
      );
      await next(tester);
      expect(find.text('원화는 정수로 입력해 주세요.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('item-amount-0')),
        '10000',
      );
      await next(tester);
      // Returning from split preserves the form and does not commit the draft.
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect((await repository.loadExpenses()).expenses, hasLength(2));
      await next(tester);
      await apply(tester);
      final saved = (await repository.loadExpenses()).expenses.last;
      expect(saved.request.rateMode, RateMode.krw);
      expect(saved.request.amountLocal, isNull);
      expect(saved.request.amountKrw, 10000);
      expect(saved.sharesKrw.values.toSet(), {2000});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Empty and failed lists are usable; reload retries', (
    tester,
  ) async {
    final repository = _Repository(MemoryExpenseRepository())
      ..hasLoadError = true;
    await tester.pumpWidget(
      MaterialApp(home: ExpenseListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('지출 목록을 불러오지 못했어요.'), findsOneWidget);
    repository.hasLoadError = false;
    repository.isEmpty = true;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('등록된 지출이 없어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('expense-add')), findsOneWidget);
  });

  testWidgets('Home tab navigation preserves sample additions', (tester) async {
    compact(tester);
    await tester.pumpWidget(const MaterialApp(home: TravelHomeScreen()));
    await tester.tap(find.widgetWithText(NavigationDestination, '경비'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('expense-add')));
    await tester.pumpAndSettle();
    await fill(tester, '탭 유지 확인', '100');
    await next(tester);
    await apply(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, '홈'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '경비'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('탭 유지 확인'));
    expect(find.text('탭 유지 확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Concurrent preview loads seed the sample list only once', () async {
    final repository = MemoryExpenseRepository();
    final results = await Future.wait([
      repository.loadExpenses(),
      repository.loadExpenses(),
    ]);
    for (final result in results) {
      expect(result.expenses, hasLength(2));
    }
  });

  testWidgets(
    'Removing an item preserves the other inputs and keyboard access',
    (tester) async {
      compact(tester);
      tester.view.physicalSize = const Size(320, 640);
      final repository = MemoryExpenseRepository();
      await tester.pumpWidget(
        MaterialApp(home: ExpenseListScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('expense-add')));
      await tester.pumpAndSettle();
      await fill(tester, '항목 삭제 테스트', '1000');
      await reveal(tester, find.text('항목 추가'));
      await tester.tap(find.text('항목 추가'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('item-name-1')));
      await tester.enterText(find.byKey(const ValueKey('item-name-1')), '맥주');
      await reveal(tester, find.byKey(const ValueKey('item-amount-1')));
      await tester.enterText(
        find.byKey(const ValueKey('item-amount-1')),
        '500',
      );
      await reveal(tester, find.text('항목 1'), delta: -160);
      await tester.tap(find.byTooltip('항목 삭제').first);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('item-name-0')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('item-name-0')))
            .controller!
            .text,
        '맥주',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('expense-next'))).bottom,
        lessThanOrEqualTo(440),
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await next(tester);
      await apply(tester);
      final saved = (await repository.loadExpenses()).expenses.last;
      expect(saved.request.items.single.amountLocal, 500);
      expect(saved.data.items.single.name, '맥주');
      expect(tester.takeException(), isNull);
    },
  );
}
