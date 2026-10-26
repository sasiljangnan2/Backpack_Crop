import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../trip/data/trip_models.dart';

enum TaskScope { private, team }

/// 할 일 → 진행 중 → 완료 (스토리보드 BP-PR-001)
enum TaskStatus {
  todo('할 일'),
  inProgress('진행 중'),
  done('완료');

  const TaskStatus(this.label);

  final String label;
}

class TripTask {
  const TripTask({
    required this.id,
    required this.scope,
    required this.title,
    required this.dueDate,
    required this.status,
    required this.creator,
    required this.assignee,
    required this.isMine,
  });

  factory TripTask.fromJson(Json json) {
    final done = json['isDone'] as bool? ?? false;
    return TripTask(
      id: json['id'] as String,
      scope: enumOf(TaskScope.values, json['scope'], TaskScope.team),
      title: json['title'] as String,
      dueDate: dateOrNull(json['dueDate']),
      status: enumOf(
        TaskStatus.values,
        json['status'],
        done ? TaskStatus.done : TaskStatus.todo,
      ),
      creator: MemberRef.fromJson(json['creator'] as Json),
      assignee: MemberRef.fromJsonOrNull(json['assignee']),
      isMine: json['isMine'] as bool? ?? false,
    );
  }

  final String id;
  final TaskScope scope;
  final String title;
  final DateTime? dueDate;
  final TaskStatus status;
  final MemberRef creator;
  final MemberRef? assignee;
  final bool isMine;

  bool get isDone => status == TaskStatus.done;

  bool isAssignedTo(String memberId) => assignee?.memberId == memberId;

  /// 오늘부터 마감일까지 남은 날 (지나면 음수)
  int? daysLeft(DateTime today) =>
      dueDate?.difference(DateTime(today.year, today.month, today.day)).inDays;
}

class TaskApi {
  const TaskApi(this._api);

  final ApiClient _api;

  Future<List<TripTask>> tasks(String tripId) async =>
      list(await _api.get('/api/trips/$tripId/tasks'), TripTask.fromJson);

  Future<TripTask> create(
    String tripId, {
    required TaskScope scope,
    required String title,
    String? assigneeMemberId,
    DateTime? dueDate,
    TaskStatus? status,
  }) async => TripTask.fromJson(
    await _api.post(
      '/api/trips/$tripId/tasks',
      body: {
        'scope': enumName(scope),
        'title': title,
        'assigneeMemberId': assigneeMemberId,
        'dueDate': ?(dueDate == null ? null : dateParam(dueDate)),
        'status': ?(status == null ? null : enumName(status)),
      },
    ) as Json,
  );

  Future<TripTask> update(
    String tripId,
    String taskId, {
    String? title,
    bool? isDone,
    TaskStatus? status,
    String? assigneeMemberId,
    bool clearAssignee = false,
    DateTime? dueDate,
  }) async => TripTask.fromJson(
    await _api.patch(
      '/api/trips/$tripId/tasks/$taskId',
      body: {
        'title': ?title,
        'isDone': ?isDone,
        'status': ?(status == null ? null : enumName(status)),
        'assigneeMemberId': ?assigneeMemberId,
        if (clearAssignee) 'clearAssignee': true,
        'dueDate': ?(dueDate == null ? null : dateParam(dueDate)),
      },
    ) as Json,
  );

  Future<void> delete(String tripId, String taskId) =>
      _api.delete('/api/trips/$tripId/tasks/$taskId');
}
