enum ReservationStatus { none, pending, confirmed }

int timeMinutes(String time) {
  final parts = time.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Calendar arithmetic never converts a date-only value from the local zone.
DateTime scheduleDate(String date) {
  final parts = date.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

String scheduleDateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class ScheduleAuthor {
  const ScheduleAuthor({required this.memberId, required this.name});
  final String memberId, name;
  factory ScheduleAuthor.fromJson(Map<String, Object?> json) => ScheduleAuthor(
    memberId: json['memberId'] as String,
    name: json['name'] as String,
  );
  Map<String, Object?> toJson() => {'memberId': memberId, 'name': name};
}

class ScheduleDraft {
  const ScheduleDraft({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.placeText,
    this.memo,
    this.reservationStatus = ReservationStatus.none,
  });
  final String day, startTime, endTime, title;
  final String? placeText, memo;
  final ReservationStatus reservationStatus;
  factory ScheduleDraft.fromJson(Map<String, Object?> json) => ScheduleDraft(
    day: json['day'] as String,
    startTime: (json['startTime'] as String).substring(0, 5),
    endTime: (json['endTime'] as String).substring(0, 5),
    title: json['title'] as String,
    placeText: json['placeText'] as String?,
    memo: json['memo'] as String?,
    reservationStatus: ReservationStatus.values.byName(
      (json['reservationStatus'] as String? ?? 'NONE').toLowerCase(),
    ),
  );
  Map<String, Object?> toJson() => {
    'day': day,
    'startTime': startTime,
    'endTime': endTime,
    'title': title.trim(),
    'placeText': placeText?.trim(),
    'memo': memo?.trim(),
    'reservationStatus': reservationStatus.name.toUpperCase(),
  };
}

class ScheduleRecord {
  const ScheduleRecord({
    required this.id,
    required this.draft,
    required this.createdBy,
    required this.version,
    required this.updatedAt,
    this.isLocked = false,
  });
  final String id;
  final ScheduleDraft draft;
  final ScheduleAuthor createdBy;
  final int version;
  final DateTime updatedAt;
  final bool isLocked;
  String get day => draft.day;
  String get startTime => draft.startTime;
  String get endTime => draft.endTime;
  String get title => draft.title;
  int get durationMinutes => timeMinutes(endTime) - timeMinutes(startTime);
  factory ScheduleRecord.fromJson(Map<String, Object?> json) => ScheduleRecord(
    id: json['id'] as String,
    draft: ScheduleDraft.fromJson(json),
    createdBy: ScheduleAuthor.fromJson(
      json['createdBy'] as Map<String, Object?>,
    ),
    version: (json['version'] as num).toInt(),
    isLocked: json['isLocked'] as bool? ?? false,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
  Map<String, Object?> toJson() => {
    ...draft.toJson(),
    'id': id,
    'createdBy': createdBy.toJson(),
    'version': version,
    'isLocked': isLocked,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
  ScheduleRecord changed({ScheduleDraft? draft, bool? isLocked}) =>
      ScheduleRecord(
        id: id,
        draft: draft ?? this.draft,
        createdBy: createdBy,
        version: version + 1,
        updatedAt: DateTime.now().toUtc(),
        isLocked: isLocked ?? this.isLocked,
      );
}

List<ScheduleRecord> overlappingSchedules(
  ScheduleDraft draft,
  Iterable<ScheduleRecord> schedules, {
  String? excludingId,
}) => schedules
    .where(
      (item) =>
          item.id != excludingId &&
          item.day == draft.day &&
          timeMinutes(draft.startTime) < timeMinutes(item.endTime) &&
          timeMinutes(draft.endTime) > timeMinutes(item.startTime),
    )
    .toList();
