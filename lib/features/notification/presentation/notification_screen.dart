import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../data/notification_api.dart';
import 'notification_navigator.dart';

/// 알림함
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<AppNotification> _items = [];
  String? _cursor;
  bool _hasNext = false;
  bool _loaded = false;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final page = await services.notifications.notifications();
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(page.content);
          _cursor = page.nextCursor;
          _hasNext = page.hasNext;
          _loaded = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _more() async {
    if (!_hasNext || _loadingMore) {
      return;
    }
    _loadingMore = true;
    try {
      final page = await services.notifications.notifications(cursor: _cursor);
      if (mounted) {
        setState(() {
          _items.addAll(page.content);
          _cursor = page.nextCursor;
          _hasNext = page.hasNext;
        });
      }
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      services.notifications.markRead(notification.id).ignore();
      setState(() {
        final index = _items.indexOf(notification);
        _items[index] = AppNotification(
          id: notification.id,
          tripId: notification.tripId,
          tripName: notification.tripName,
          type: notification.type,
          message: notification.message,
          refType: notification.refType,
          refId: notification.refId,
          isRead: true,
          createdAt: notification.createdAt,
        );
      });
    }
    if (notification.type == NotificationType.tripDeleted) {
      return;
    }
    await openNotificationTarget(
      Navigator.of(context),
      tripId: notification.tripId,
      refType: enumNameOf(notification.refType),
      refId: notification.refId,
    );
  }

  Future<void> _readAll() async {
    try {
      await services.notifications.markAllRead();
      await _reload();
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  IconData _icon(NotificationType type) => switch (type) {
    NotificationType.scheduleChanged => Icons.calendar_month_outlined,
    NotificationType.expenseAdded => Icons.receipt_long_outlined,
    NotificationType.settlementShared => Icons.payments_outlined,
    NotificationType.tripDeleted => Icons.delete_outline,
    NotificationType.pollCreated ||
    NotificationType.pollClosed => Icons.how_to_vote_outlined,
    NotificationType.taskAssigned => Icons.checklist,
    NotificationType.memberJoined => Icons.person_add_alt_1_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          if (_items.any((n) => !n.isRead))
            TextButton(onPressed: _readAll, child: const Text('모두 읽음')),
        ],
      ),
      body: !_loaded
          ? (_error == null
                ? const LoadingView()
                : ErrorView(error: _error!, onRetry: _reload))
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 300) {
                  _more();
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: _reload,
                child: _items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 60),
                          EmptyView(
                            icon: Icons.notifications_none,
                            title: '새 알림이 없어요',
                            message: '일정이 바뀌거나 지출이 등록되면 알려 드려요.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final n = _items[index];
                          return ListTile(
                            tileColor: n.isRead
                                ? null
                                : AppColors.primarySoft.withValues(alpha: .5),
                            onTap: () => _open(n),
                            leading: CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(
                                _icon(n.type),
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              n.message,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: n.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${n.tripName} · ${Fmt.ago(n.createdAt)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}

String? enumNameOf(NotificationRefType type) => switch (type) {
  NotificationRefType.none => null,
  NotificationRefType.schedule => 'SCHEDULE',
  NotificationRefType.expense => 'EXPENSE',
  NotificationRefType.settlementShare => 'SETTLEMENT_SHARE',
  NotificationRefType.poll => 'POLL',
  NotificationRefType.task => 'TASK',
  NotificationRefType.trip => 'TRIP',
};
