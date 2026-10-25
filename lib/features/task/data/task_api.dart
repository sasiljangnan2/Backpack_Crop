import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../trip/data/trip_models.dart';

enum TaskScope { private, team }

class TripTask {
  const TripTask({
    required this.id,
    required this.scope,
    required this.title,
    required this.isDone,
    required this.creator,
    required this.assignee,
    required this.isMine,
  });

  factory TripTask.fromJson(Json json) => TripTask(
    id: json['id'] as String,
    scope: enumOf(TaskScope.values, json['scope'], TaskScope.team),
    title: json['title'] as String,
    isDone: json['isDone'] as bool? ?? false,
    creator: MemberRef.fromJson(json['creator'] as Json),
    assignee: MemberRef.fromJsonOrNull(json['assignee']),
    isMine: json['isMine'] as bool? ?? false,
  );

  final String id;
  final TaskScope scope;
  final String title;
  final bool isDone;
  final MemberRef creator;
  final MemberRef? assignee;
  final bool isMine;
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
  }) async => TripTask.fromJson(
    await _api.post(
      '/api/trips/$tripId/tasks',
      body: {
        'scope': enumName(scope),
        'title': title,
        'assigneeMemberId': assigneeMemberId,
      },
    ) as Json,
  );

  Future<TripTask> update(
    String tripId,
    String taskId, {
    String? title,
    bool? isDone,
    String? assigneeMemberId,
    bool clearAssignee = false,
  }) async => TripTask.fromJson(
    await _api.patch(
      '/api/trips/$tripId/tasks/$taskId',
      body: {
        'title': ?title,
        'isDone': ?isDone,
        'assigneeMemberId': ?assigneeMemberId,
        if (clearAssignee) 'clearAssignee': true,
      },
    ) as Json,
  );

  Future<void> delete(String tripId, String taskId) =>
      _api.delete('/api/trips/$tripId/tasks/$taskId');
}
