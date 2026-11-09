import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

enum NotificationType {
  scheduleChanged,
  expenseAdded,
  settlementShared,
  tripDeleted,
  pollCreated,
  pollClosed,
  taskAssigned,
  memberJoined,
}

enum NotificationRefType {
  schedule,
  expense,
  settlementShare,
  poll,
  task,
  trip,
  none,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.tripId,
    required this.tripName,
    required this.type,
    required this.message,
    required this.refType,
    required this.refId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Json json) => AppNotification(
    id: json['id'] as String,
    tripId: json['tripId'] as String,
    tripName: json['tripName'] as String,
    type: enumOf(
      NotificationType.values,
      json['type'],
      NotificationType.scheduleChanged,
    ),
    message: json['message'] as String,
    refType: enumOf(
      NotificationRefType.values,
      json['refType'],
      NotificationRefType.none,
    ),
    refId: json['refId'] as String?,
    isRead: json['isRead'] as bool? ?? false,
    createdAt: instant(json['createdAt']),
  );

  final String id;
  final String tripId;
  final String tripName;
  final NotificationType type;
  final String message;
  final NotificationRefType refType;
  final String? refId;
  final bool isRead;
  final DateTime createdAt;
}

class NotificationPage {
  const NotificationPage(this.content, this.nextCursor, this.hasNext);

  final List<AppNotification> content;
  final String? nextCursor;
  final bool hasNext;
}

class NotificationApi {
  const NotificationApi(this._api);

  final ApiClient _api;

  Future<NotificationPage> notifications({String? cursor}) async {
    final json = await _api.get(
      '/api/notifications',
      query: {'cursor': cursor, 'size': 30},
    ) as Json;
    return NotificationPage(
      list(json['content'], AppNotification.fromJson),
      json['nextCursor'] as String?,
      json['hasNext'] as bool? ?? false,
    );
  }

  Future<int> unreadCount() async => integer(
    (await _api.get('/api/notifications/unread-count') as Json)['count'],
  );

  Future<void> markRead(String id) => _api.patch('/api/notifications/$id/read');

  Future<void> markAllRead() => _api.patch('/api/notifications/read-all');

  Future<void> registerDevice(String token) =>
      _api.put('/api/device-tokens', body: {'fcmToken': token});

  Future<void> removeDevice(String token) =>
      _api.delete('/api/device-tokens', body: {'fcmToken': token});
}
