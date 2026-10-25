import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import 'notification_screen.dart';

/// 종 모양 알림 버튼. 읽지 않은 알림 수를 배지로 보여 주고, 1분마다·푸시를 받을 때 다시 센다.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.color = AppColors.ink});

  final Color color;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    services.push.received.addListener(_refresh);
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    services.push.received.removeListener(_refresh);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final count = await services.notifications.unreadCount();
      if (mounted && count != _count) {
        setState(() => _count = count);
      }
    } catch (_) {
      // 배지는 보조 정보다. 실패해도 조용히 넘어간다
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '알림',
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationScreen()),
        );
        _refresh();
      },
      icon: Badge(
        isLabelVisible: _count > 0,
        label: Text(_count > 99 ? '99+' : '$_count'),
        child: Icon(Icons.notifications_none, color: widget.color),
      ),
    );
  }
}
