import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/common.dart';
import '../../expense/presentation/expense_tab.dart';
import '../../schedule/presentation/schedule_tab.dart';
import '../../task/presentation/prep_tab.dart';
import '../data/trip_models.dart';
import 'trip_home_tab.dart';

/// 여행 화면들이 함께 쓰는 여행 정보. `TripScope.of(context).trip`
class TripScope extends InheritedWidget {
  const TripScope({
    super.key,
    required this.trip,
    required this.reload,
    required this.selectTab,
    required this.revision,
    required this.tab,
    required super.child,
  });

  final TripDetail trip;
  final Future<void> Function() reload;
  final void Function(int tab) selectTab;

  /// 다른 탭에서 데이터가 바뀌면 올라간다 (홈 카드가 다시 불러오는 신호)
  final int revision;

  /// 지금 보이는 탭 ([TripShell.home] 등)
  final int tab;

  static TripScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripScope>()!;

  @override
  bool updateShouldNotify(TripScope oldWidget) =>
      trip != oldWidget.trip ||
      revision != oldWidget.revision ||
      tab != oldWidget.tab;
}

/// 탭이 다시 보일 때마다 [onTabShown]을 부른다.
/// IndexedStack의 탭은 한 번 만들어지면 계속 살아 있어서, 그 사이 다른 멤버가
/// 바꾼 내용을 보려면 다시 불러와야 한다. 처음 만들 때는 각 탭이 직접 불러오므로 부르지 않는다
mixin TripTabRefresh<T extends StatefulWidget> on State<T> {
  int get tabIndex;

  void onTabShown();

  bool? _shown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = TripScope.of(context).tab == tabIndex;
    if (_shown == false && shown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          onTabShown();
        }
      });
    }
    _shown = shown;
  }
}

class TripShell extends StatefulWidget {
  const TripShell({super.key, required this.tripId, this.initialTab = 0});

  final String tripId;
  final int initialTab;

  static const home = 0;
  static const schedule = 1;
  static const expense = 2;
  static const prep = 3;

  @override
  State<TripShell> createState() => _TripShellState();
}

class _TripShellState extends State<TripShell> {
  late int _tab = widget.initialTab;
  TripDetail? _trip;
  Object? _error;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [refreshCards]가 false면 여행 정보(멤버 등)만 바꾸고 홈 카드는 다시 부르지 않는다
  Future<void> _load({bool refreshCards = true}) async {
    try {
      final trip = await services.trips.trip(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _error = null;
          if (refreshCards) {
            _revision++;
          }
        });
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      // 여행이 지워졌거나 내가 나간 여행이면 목록으로 돌아간다
      if (e.code == 'NOT_TRIP_MEMBER') {
        showSnack(context, '더 이상 참여 중인 여행이 아니에요.');
        Navigator.of(context).pop();
        return;
      }
      setState(() => _error = e);
    }
  }

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    // 그 사이 멤버가 들어오거나 나갔을 수 있으니 여행 정보를 조용히 다시 받는다.
    // 홈으로 올 때는 홈 카드도 최신 값으로 다시 부른다
    _load(refreshCards: tab == TripShell.home);
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null
            ? const LoadingView()
            : ErrorView(error: _error!, onRetry: _load),
      );
    }
    return TripScope(
      trip: trip,
      reload: _load,
      revision: _revision,
      tab: _tab,
      selectTab: _selectTab,
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: const [
            TripHomeTab(),
            ScheduleTab(),
            ExpenseTab(),
            PrepTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: '일정',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: '경비',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: '준비',
            ),
          ],
        ),
      ),
    );
  }
}
