import '../../../core/network/json.dart';

enum TripStatus { upcoming, live, done }

enum MemberRole { host, member, guest }

/// 응답에 들어가는 멤버 한 명. 지출·정산은 사용자 ID가 아니라 멤버 ID로 사람을 가리킨다.
class MemberRef {
  const MemberRef({required this.memberId, required this.name});

  factory MemberRef.fromJson(Json json) => MemberRef(
    memberId: json['memberId'] as String,
    name: json['name'] as String,
  );

  static MemberRef? fromJsonOrNull(Object? json) =>
      json == null ? null : MemberRef.fromJson(json as Json);

  final String memberId;
  final String name;

  /// 아바타에 쓰는 첫 글자
  String get initial => name.isEmpty ? '?' : name.characters.first;
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}

class TripSummary {
  const TripSummary({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.currencyCode,
    required this.status,
    required this.dDay,
    required this.dayNo,
    required this.memberCount,
    required this.myRole,
  });

  factory TripSummary.fromJson(Json json) => TripSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    destination: json['destination'] as String,
    startDate: date(json['startDate']),
    endDate: date(json['endDate']),
    currencyCode: json['currencyCode'] as String,
    status: enumOf(TripStatus.values, json['status'], TripStatus.upcoming),
    dDay: integer(json['dDay']),
    dayNo: integerOrNull(json['dayNo']),
    memberCount: integer(json['memberCount']),
    myRole: enumOf(MemberRole.values, json['myRole'], MemberRole.member),
  );

  final String id;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String currencyCode;
  final TripStatus status;
  final int dDay;
  final int? dayNo;
  final int memberCount;
  final MemberRole myRole;
}

class TripMember {
  const TripMember({
    required this.memberId,
    required this.name,
    required this.role,
    required this.isMe,
    required this.prepaidRate,
  });

  factory TripMember.fromJson(Json json) => TripMember(
    memberId: json['memberId'] as String,
    name: json['name'] as String,
    role: enumOf(MemberRole.values, json['role'], MemberRole.member),
    isMe: json['isMe'] as bool? ?? false,
    prepaidRate: decimalOrNull(json['prepaidRate']),
  );

  final String memberId;
  final String name;
  final MemberRole role;
  final bool isMe;
  final double? prepaidRate;

  MemberRef get ref => MemberRef(memberId: memberId, name: name);
}

class TripDetail {
  const TripDetail({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.nights,
    required this.currencyCode,
    required this.timeZone,
    required this.inviteCode,
    required this.status,
    required this.dDay,
    required this.dayNo,
    required this.myMemberId,
    required this.myRole,
    required this.members,
  });

  factory TripDetail.fromJson(Json json) => TripDetail(
    id: json['id'] as String,
    name: json['name'] as String,
    destination: json['destination'] as String,
    startDate: date(json['startDate']),
    endDate: date(json['endDate']),
    nights: integer(json['nights']),
    currencyCode: json['currencyCode'] as String,
    timeZone: json['timeZone'] as String,
    inviteCode: json['inviteCode'] as String,
    status: enumOf(TripStatus.values, json['status'], TripStatus.upcoming),
    dDay: integer(json['dDay']),
    dayNo: integerOrNull(json['dayNo']),
    myMemberId: json['myMemberId'] as String,
    myRole: enumOf(MemberRole.values, json['myRole'], MemberRole.member),
    members: list(json['members'], TripMember.fromJson),
  );

  final String id;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int nights;
  final String currencyCode;
  final String timeZone;
  final String inviteCode;
  final TripStatus status;
  final int dDay;
  final int? dayNo;
  final String myMemberId;
  final MemberRole myRole;
  final List<TripMember> members;

  bool get isHost => myRole == MemberRole.host;
  bool get isKrwTrip => currencyCode == 'KRW';
  int get days => nights + 1;

  TripMember get me => members.firstWhere(
    (m) => m.memberId == myMemberId,
    orElse: () => members.first,
  );

  /// 여행 첫날부터 마지막 날까지
  List<DateTime> get dates => [
    for (int i = 0; i < days; i++)
      DateTime(startDate.year, startDate.month, startDate.day + i),
  ];

  /// 날짜가 여행 며칠째인지 (1부터)
  int dayNumberOf(DateTime day) =>
      DateTime(day.year, day.month, day.day).difference(startDate).inDays + 1;
}
