import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/common.dart';
import '../../expense/presentation/expense_detail_screen.dart';
import '../../schedule/presentation/poll_screens.dart';
import '../../settlement/presentation/settlement_screen.dart';
import '../../trip/presentation/trip_shell.dart';

/// 알림을 눌렀을 때(알림함 · 푸시) 해당 화면으로 이동한다.
/// 여행 화면을 연 뒤, 대상이 있으면 그 위에 상세 화면을 연다.
Future<void> openNotificationTarget(
  NavigatorState navigator, {
  required String tripId,
  String? refType,
  String? refId,
}) async {
  final context = navigator.context;
  final tab = switch (refType) {
    'SCHEDULE' || 'POLL' || 'TRIP' => TripShell.schedule,
    'EXPENSE' || 'SETTLEMENT_SHARE' => TripShell.expense,
    'TASK' => TripShell.prep,
    _ => TripShell.home,
  };
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => TripShell(tripId: tripId, initialTab: tab),
    ),
  );
  if (refId == null ||
      (refType != 'EXPENSE' &&
          refType != 'POLL' &&
          refType != 'SETTLEMENT_SHARE')) {
    return;
  }
  try {
    final trip = await services.trips.trip(tripId);
    final Widget screen = switch (refType) {
      'EXPENSE' => ExpenseDetailScreen(trip: trip, expenseId: refId),
      'POLL' => PollDetailScreen(trip: trip, pollId: refId),
      _ => SettlementShareScreen(trip: trip, shareId: refId),
    };
    await navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
  } on ApiException catch (e) {
    if (context.mounted) {
      showError(context, e);
    }
  }
}
