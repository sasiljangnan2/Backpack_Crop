import 'dart:async';
import 'dart:convert';

import 'package:backpack/features/expense/data/expense_request.dart';
import 'package:backpack/features/expense/data/expense_split_repository.dart';
import 'package:backpack/features/expense/data/sample_expense_split_repository.dart';
import 'package:backpack/features/expense/presentation/expense_split_controller.dart';
import 'package:backpack/features/expense/presentation/expense_split_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements ExpenseSplitRepository {
  _Repository(this.load);
  final Future<ExpenseSplitData> Function() load;

  @override
  Future<ExpenseSplitData> loadSplitData() => load();
}

void main() {
  test(
    'ITEM request follows documented fields and excludes preview amounts',
    () async {
      final controller = ExpenseSplitController(
        const SampleExpenseSplitRepository(),
      );
      addTearDown(controller.dispose);
      expect(controller.createRequest(), isNull);
      await controller.load();
      final request = controller.createRequest()!;
      final json = request.toJson();
      expect(json, {
        'payerMemberId': '019d0d00-0000-7000-8000-000000000001',
        'title': '이치란 라멘 난바점',
        'category': 'FOOD',
        'paidDate': '2026-11-01',
        'rateMode': 'MANUAL',
        'amountLocal': 7360,
        'manualRate': 9.35,
        'amountKrw': null,
        'splitMethod': 'ITEM',
        'items': [
          {
            'name': '돈코츠 라멘',
            'amountLocal': 4900,
            'amountKrw': null,
            'members': [
              for (var n = 1; n <= 5; n++)
                {'memberId': '019d0d00-0000-7000-8000-00000000000$n'},
            ],
          },
          {
            'name': '생맥주',
            'amountLocal': 1650,
            'amountKrw': null,
            'members': [
              for (final n in [1, 3, 4])
                {'memberId': '019d0d00-0000-7000-8000-00000000000$n'},
            ],
          },
          {
            'name': '교자',
            'amountLocal': 390,
            'amountKrw': null,
            'members': [
              for (final n in [2, 5])
                {'memberId': '019d0d00-0000-7000-8000-00000000000$n'},
            ],
          },
          {
            'name': '차슈 추가',
            'amountLocal': 420,
            'amountKrw': null,
            'members': [
              {'memberId': '019d0d00-0000-7000-8000-000000000002'},
            ],
          },
        ],
      });
      final decoded = jsonDecode(jsonEncode(json)) as Map<String, Object?>;
      expect(ExpenseRequest.fromJson(decoded).toJson(), json);
    },
  );

  test(
    'Equal request collapses items; switching back restores ID selections',
    () async {
      final controller = ExpenseSplitController(
        const SampleExpenseSplitRepository(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      final memberId = controller.data!.members.last.memberId;
      controller.toggleMember(0, memberId, isSelected: false);
      controller.setPayer(memberId);
      final itemRequest = controller.createRequest()!;
      expect(
        itemRequest.items.first.members.map((member) => member.memberId),
        isNot(contains(memberId)),
      );
      controller.setEqual(true);
      final equal = controller.createRequest()!;
      expect(equal.splitMethod, SplitMethod.equal);
      expect(equal.items, hasLength(1));
      expect(equal.items.single.amountLocal, 7360);
      expect(equal.items.single.members, hasLength(5));
      expect(equal.payerMemberId, memberId);
      controller.setEqual(false);
      expect(controller.createRequest()!.toJson(), itemRequest.toJson());
      for (final member in controller.data!.members) {
        controller.toggleMember(0, member.memberId, isSelected: false);
      }
      expect(controller.createRequest(), isNull);
    },
  );

  test(
    'Same names and different list order do not change member identity',
    () async {
      final fixture = await const SampleExpenseSplitRepository()
          .loadSplitData();
      final members = fixture.members.reversed
          .map(
            (member) =>
                ExpenseSplitMember(memberId: member.memberId, name: '동명이인'),
          )
          .toList();
      final data = ExpenseSplitData(
        tripName: fixture.tripName,
        title: fixture.title,
        paidDate: fixture.paidDate,
        payerMemberId: fixture.payerMemberId,
        previewRate: fixture.previewRate,
        members: members,
        items: fixture.items,
      );
      final controller = ExpenseSplitController(_Repository(() async => data));
      addTearDown(controller.dispose);
      await controller.load();
      controller.toggleMember(0, members.first.memberId, isSelected: false);
      final request = controller.createRequest()!;
      expect(request.payerMemberId, fixture.payerMemberId);
      expect(
        request.items.first.members.map((member) => member.memberId).toSet(),
        fixture.members.take(4).map((member) => member.memberId).toSet(),
      );
      expect(fixture.items.first.memberIds, hasLength(5));
    },
  );

  test('Disposing during load does not notify a dead screen', () async {
    final pending = Completer<ExpenseSplitData>();
    final controller = ExpenseSplitController(
      _Repository(() => pending.future),
    );
    final loading = controller.load();
    controller.dispose();
    pending.complete(
      await const SampleExpenseSplitRepository().loadSplitData(),
    );
    await expectLater(loading, completes);
  });

  testWidgets('Loading, failure and retry appear without duplicate requests', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<ExpenseSplitData>();
    final repository = _Repository(() {
      calls++;
      if (calls == 1) {
        return pending.future;
      }
      return const SampleExpenseSplitRepository().loadSplitData();
    });
    await tester.pumpWidget(
      MaterialApp(home: ExpenseSplitScreen(repository: repository)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump();
    expect(calls, 1);
    pending.completeError(StateError('sample failure'));
    await tester.pumpAndSettle();
    expect(find.text('경비 정보를 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('이치란 라멘 난바점'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
