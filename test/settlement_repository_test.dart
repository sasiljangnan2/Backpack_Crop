import 'dart:async';
import 'dart:convert';

import 'package:backpack/core/network/api_client.dart';
import 'package:backpack/core/network/session_tokens.dart';
import 'package:backpack/features/expense/data/expense_repository.dart';
import 'package:backpack/features/expense/data/memory_expense_repository.dart';
import 'package:backpack/features/settlement/data/settlement_models.dart';
import 'package:backpack/features/settlement/data/settlement_repository.dart';
import 'package:backpack/features/settlement/data/preview_settlement_repository.dart';
import 'package:backpack/features/settlement/presentation/settlement_controller.dart';
import 'package:backpack/features/settlement/presentation/settlement_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'support/auth_trip_fixture.dart';
import 'support/settlement_fixture.dart';

class PendingRepository implements SettlementRepository {
  final requests = <Completer<SettlementSnapshot>>[];
  @override
  Future<SettlementSnapshot> load() {
    final request = Completer<SettlementSnapshot>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  test(
    'Settlement GET preserves server transfer order and authenticated contract',
    () async {
      final expected = settlementFixture();
      final store = MemorySessionStore()
        ..current = const SessionTokens(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
        );
      final api = ApiClient(
        store: store,
        baseUrl: 'http://fixture',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'http://fixture/api/trips/trip%2Fidentifier/settlement',
          );
          expect(request.headers['Authorization'], 'Bearer test-access');
          expect(request.body, isEmpty);
          return jsonResponse(200, expected.toJson());
        }),
      );
      addTearDown(api.close);
      final result = await ApiSettlementRepository(
        api,
        'trip/identifier',
      ).load();
      expect(result.toJson(), expected.toJson());
      expect(result.member('a')!.balanceKrw, 4000);
      expect(result.transfers.first.from.memberId, 'b');
    },
  );

  test(
    'Fractional KRW, inconsistent totals and transfer debts are rejected',
    () {
      Map<String, Object?> fresh() =>
          jsonDecode(jsonEncode(settlementFixture().toJson()))
              as Map<String, Object?>;
      final bad = fresh()..['totalKrw'] = 24000.5;
      expect(() => SettlementSnapshot.fromJson(bad), throwsFormatException);
      expect(
        () => SettlementSnapshot.fromJson(fresh()..['totalKrw'] = 24001),
        throwsFormatException,
      );
      final wrong = fresh();
      ((wrong['transfers'] as List).first as Map)['amountKrw'] = 3999;
      expect(() => SettlementSnapshot.fromJson(wrong), throwsFormatException);
      final negative = fresh();
      ((negative['members'] as List).first as Map)['paidKrw'] = -1;
      expect(
        () => SettlementSnapshot.fromJson(negative),
        throwsFormatException,
      );
      final duplicate = fresh();
      ((duplicate['members'] as List)[1] as Map)['memberId'] = 'a';
      expect(
        () => SettlementSnapshot.fromJson(duplicate),
        throwsFormatException,
      );
    },
  );

  test(
    'Preview uses saved rounded shares and all transfers settle the balances',
    () async {
      final overview = await MemoryExpenseRepository().loadExpenses();
      final snapshot = previewSettlement(overview);
      expect(snapshot.totalKrw, 162316);
      expect(snapshot.members[0].paidKrw, 68816);
      expect(snapshot.members[0].shareKrw, 33005);
      expect(snapshot.members[0].balanceKrw, 35811);
      expect(snapshot.members[1].balanceKrw, 59887);
      for (final member in snapshot.members) {
        final received = snapshot.transfers
            .where((item) => item.to.memberId == member.person.memberId)
            .fold(0, (sum, item) => sum + item.amountKrw);
        final sent = snapshot.transfers
            .where((item) => item.from.memberId == member.person.memberId)
            .fold(0, (sum, item) => sum + item.amountKrw);
        expect(received - sent, member.balanceKrw);
      }
    },
  );

  test('Shared expense edits refresh settlement without duplicating or crossing trips', () async {
    final expenses = MemoryExpenseRepository(trip: settlementExpenseTrip());
    final other = MemoryExpenseRepository(trip: settlementExpenseTrip());
    final repo = PreviewSettlementRepository(expenses);
    expect((await repo.load()).totalKrw, 0);
    await expenses.saveExpense(settlementExpense(amount: 12001));
    final first = await repo.load();
    expect(first.member('a')!.shareKrw, 6000);
    expect(first.member('b')!.shareKrw, 6001);
    expect(first.transfers.single.amountKrw, 6001);
    await expenses.saveExpense(settlementExpense(amount: 18000));
    expect((await repo.load()).totalKrw, 18000);
    expect((await repo.load()).transfers.single.amountKrw, 9000);
    expect((await PreviewSettlementRepository(other).load()).totalKrw, 0);
    final overview = await expenses.loadExpenses();
    final old = overview.expenses.single;
    final invalid = ExpenseRecord(
      id: old.id,
      data: old.data,
      request: old.request,
      amountKrw: old.amountKrw,
      sharesKrw: {'a': 0, 'unknown': 18000},
    );
    expect(
      () => previewSettlement(
        ExpenseOverview(trip: overview.trip, expenses: [invalid]),
      ),
      throwsFormatException,
    );
  });

  test(
    'Latest load wins and failed refresh preserves prior result with an error',
    () async {
      final repo = PendingRepository();
      final controller = SettlementController(
        repository: repo,
        currentMemberId: 'a',
      );
      final first = controller.load(), second = controller.load();
      repo.requests[1].complete(settlementFixture(isBalanced: true));
      await second;
      repo.requests[0].complete(settlementFixture());
      await first;
      expect(controller.me!.balanceKrw, 0);
      final lastTime = controller.checkedAt;
      final third = controller.load();
      repo.requests[2].completeError(StateError('offline'));
      await third;
      expect(controller.me!.balanceKrw, 0);
      expect(controller.checkedAt, lastTime);
      expect(controller.error, SettlementStrings.loadError);
      expect(controller.isLoading, isFalse);
      final late = controller.load();
      controller.dispose();
      repo.requests[3].complete(settlementFixture());
      await late;
    },
  );

  test(
    'Empty and balanced states differ and whole won amounts retain every digit',
    () {
      expect(settlementFixture(isEmpty: true).totalKrw, 0);
      final balanced = settlementFixture(isBalanced: true);
      expect(balanced.totalKrw, 24000);
      expect(balanced.transfers, isEmpty);
      expect(SettlementStrings.krw(123456789012), '123,456,789,012원');
      expect(SettlementStrings.status(-1), SettlementStrings.send);
      expect(SettlementStrings.status(1), SettlementStrings.receive);
    },
  );
}
