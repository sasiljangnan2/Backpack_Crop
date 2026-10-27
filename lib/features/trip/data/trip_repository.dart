import '../../../core/network/api_client.dart';

enum TripRole { host, member, guest }

class TripSummary {
  const TripSummary({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.currencyCode,
    required this.memberCount,
    required this.myRole,
  });
  final String id, name, destination, startDate, endDate, currencyCode;
  final int memberCount;
  final TripRole myRole;
  factory TripSummary.fromJson(Map<String, Object?> json) => TripSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    destination: json['destination'] as String,
    startDate: json['startDate'] as String,
    endDate: json['endDate'] as String,
    currencyCode: json['currencyCode'] as String,
    memberCount: (json['memberCount'] as num).toInt(),
    myRole: TripRole.values.byName((json['myRole'] as String).toLowerCase()),
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'destination': destination,
    'startDate': startDate,
    'endDate': endDate,
    'currencyCode': currencyCode,
    'memberCount': memberCount,
    'myRole': myRole.name.toUpperCase(),
  };
}

class TripDetail {
  const TripDetail({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.currencyCode,
    required this.inviteCode,
    required this.myMemberId,
    required this.myRole,
    required this.createdAt,
  });
  final String id,
      name,
      destination,
      startDate,
      endDate,
      currencyCode,
      inviteCode,
      myMemberId;
  final TripRole myRole;
  final DateTime createdAt;
  factory TripDetail.fromJson(Map<String, Object?> json) => TripDetail(
    id: json['id'] as String,
    name: json['name'] as String,
    destination: json['destination'] as String,
    startDate: json['startDate'] as String,
    endDate: json['endDate'] as String,
    currencyCode: json['currencyCode'] as String,
    inviteCode: json['inviteCode'] as String,
    myMemberId: json['myMemberId'] as String,
    myRole: TripRole.values.byName((json['myRole'] as String).toLowerCase()),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'destination': destination,
    'startDate': startDate,
    'endDate': endDate,
    'currencyCode': currencyCode,
    'inviteCode': inviteCode,
    'myMemberId': myMemberId,
    'myRole': myRole.name.toUpperCase(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
  TripSummary toSummary({required int memberCount}) => TripSummary(
    id: id,
    name: name,
    destination: destination,
    startDate: startDate,
    endDate: endDate,
    currencyCode: currencyCode,
    memberCount: memberCount,
    myRole: myRole,
  );
}

class TripMember {
  const TripMember({
    required this.memberId,
    required this.name,
    required this.role,
    required this.isMe,
    required this.joinedAt,
    this.prepaidRate,
  });
  final String memberId, name;
  final TripRole role;
  final bool isMe;
  final num? prepaidRate;
  final DateTime joinedAt;
  factory TripMember.fromJson(Map<String, Object?> json) => TripMember(
    memberId: json['memberId'] as String,
    name: json['name'] as String,
    role: TripRole.values.byName((json['role'] as String).toLowerCase()),
    isMe: json['isMe'] as bool,
    prepaidRate: json['prepaidRate'] as num?,
    joinedAt: DateTime.parse(json['joinedAt'] as String),
  );
  Map<String, Object?> toJson() => {
    'memberId': memberId,
    'name': name,
    'role': role.name.toUpperCase(),
    'isMe': isMe,
    'prepaidRate': prepaidRate,
    'joinedAt': joinedAt.toUtc().toIso8601String(),
  };
}

class TripCreateRequest {
  const TripCreateRequest({
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.currencyCode,
  });
  final String name, destination, startDate, endDate, currencyCode;
  factory TripCreateRequest.fromJson(Map<String, Object?> json) =>
      TripCreateRequest(
        name: json['name'] as String,
        destination: json['destination'] as String,
        startDate: json['startDate'] as String,
        endDate: json['endDate'] as String,
        currencyCode: json['currencyCode'] as String,
      );
  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'destination': destination.trim(),
    'startDate': startDate,
    'endDate': endDate,
    'currencyCode': currencyCode,
  };
}

abstract interface class TripRepository {
  Future<List<TripSummary>> list();
  Future<TripDetail> create(TripCreateRequest request);
  Future<TripDetail> detail(String tripId);
  Future<List<TripMember>> members(String tripId);
  Future<TripDetail> join(String code);
}

class ApiTripRepository implements TripRepository {
  const ApiTripRepository(this.api);
  final ApiClient api;
  @override
  Future<List<TripSummary>> list() async =>
      (await api.get('/api/trips') as List<Object?>)
          .map((item) => TripSummary.fromJson(item as Map<String, Object?>))
          .toList();
  @override
  Future<TripDetail> create(TripCreateRequest request) async =>
      TripDetail.fromJson(
        await api.post('/api/trips', body: request.toJson())
            as Map<String, Object?>,
      );
  @override
  Future<TripDetail> detail(String tripId) async => TripDetail.fromJson(
    await api.get('/api/trips/${Uri.encodeComponent(tripId)}')
        as Map<String, Object?>,
  );
  @override
  Future<List<TripMember>> members(String tripId) async =>
      (await api.get('/api/trips/${Uri.encodeComponent(tripId)}/members')
              as List<Object?>)
          .map((item) => TripMember.fromJson(item as Map<String, Object?>))
          .toList();
  @override
  Future<TripDetail> join(String code) async => TripDetail.fromJson(
    await api.post(
      '/api/trips/join',
      body: {'inviteCode': code.trim().toUpperCase()},
    ) as Map<String, Object?>,
  );
}
