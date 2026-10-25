import 'package:flutter/material.dart';

import '../../../core/network/json.dart';
import '../../trip/data/trip_models.dart';

enum ScheduleStatus { planned, inProgress, done }

enum ReservationStatus { none, pending, confirmed }

class ScheduleActivity {
  const ScheduleActivity({
    required this.actualStartTime,
    required this.actualEndTime,
    required this.delayMin,
    required this.recordedBy,
  });

  factory ScheduleActivity.fromJson(Json json) => ScheduleActivity(
    actualStartTime: time(json['actualStartTime']),
    actualEndTime: time(json['actualEndTime']),
    delayMin: integer(json['delayMin']),
    recordedBy: MemberRef.fromJson(json['recordedBy'] as Json),
  );

  final TimeOfDay actualStartTime;
  final TimeOfDay actualEndTime;
  final int delayMin;
  final MemberRef recordedBy;
}

class Schedule {
  const Schedule({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.placeText,
    required this.isLocked,
    required this.reservationStatus,
    required this.memo,
    required this.status,
    required this.activity,
    required this.createdBy,
    required this.version,
  });

  factory Schedule.fromJson(Json json) => Schedule(
    id: json['id'] as String,
    day: date(json['day']),
    startTime: time(json['startTime']),
    endTime: time(json['endTime']),
    title: json['title'] as String,
    placeText: json['placeText'] as String?,
    isLocked: json['isLocked'] as bool? ?? false,
    reservationStatus: enumOf(
      ReservationStatus.values,
      json['reservationStatus'],
      ReservationStatus.none,
    ),
    memo: json['memo'] as String?,
    status: enumOf(
      ScheduleStatus.values,
      json['status'],
      ScheduleStatus.planned,
    ),
    activity: json['activity'] == null
        ? null
        : ScheduleActivity.fromJson(json['activity'] as Json),
    createdBy: MemberRef.fromJson(json['createdBy'] as Json),
    version: integer(json['version']),
  );

  final String id;
  final DateTime day;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String title;
  final String? placeText;
  final bool isLocked;
  final ReservationStatus reservationStatus;
  final String? memo;
  final ScheduleStatus status;
  final ScheduleActivity? activity;
  final MemberRef createdBy;
  final int version;

  int get durationMinutes =>
      (endTime.hour * 60 + endTime.minute) -
      (startTime.hour * 60 + startTime.minute);
}

class NextFixed {
  const NextFixed({required this.schedule, required this.minutesUntil});

  final Schedule schedule;
  final int minutesUntil;
}

/// 오늘 요약 (여행지 현지 기준)
class TodaySummary {
  const TodaySummary({
    required this.date,
    required this.localTime,
    required this.tripStatus,
    required this.dayNo,
    required this.current,
    required this.next,
    required this.nextFixed,
    required this.delayMin,
    required this.doneCount,
    required this.total,
    required this.remaining,
    required this.schedules,
  });

  factory TodaySummary.fromJson(Json json) {
    final fixed = json['nextFixed'] as Json?;
    return TodaySummary(
      date: parseDate(json['date']),
      localTime: time(json['localTime']),
      tripStatus: enumOf(
        TripStatus.values,
        json['tripStatus'],
        TripStatus.upcoming,
      ),
      dayNo: integerOrNull(json['dayNo']),
      current: json['current'] == null
          ? null
          : Schedule.fromJson(json['current'] as Json),
      next: json['next'] == null
          ? null
          : Schedule.fromJson(json['next'] as Json),
      nextFixed: fixed == null
          ? null
          : NextFixed(
              schedule: Schedule.fromJson(fixed['schedule'] as Json),
              minutesUntil: integer(fixed['minutesUntil']),
            ),
      delayMin: integer(json['delayMin']),
      doneCount: integer(json['doneCount']),
      total: integer(json['total']),
      remaining: integer(json['remaining']),
      schedules: list(json['schedules'], Schedule.fromJson),
    );
  }

  final DateTime date;
  final TimeOfDay localTime;
  final TripStatus tripStatus;
  final int? dayNo;
  final Schedule? current;
  final Schedule? next;
  final NextFixed? nextFixed;
  final int delayMin;
  final int doneCount;
  final int total;
  final int remaining;
  final List<Schedule> schedules;
}

enum PollStatus { open, closed }

class PollOption {
  const PollOption({
    required this.id,
    required this.label,
    required this.memo,
    required this.voteCount,
    required this.isLeading,
    required this.voters,
  });

  factory PollOption.fromJson(Json json) => PollOption(
    id: json['id'] as String,
    label: json['label'] as String,
    memo: json['memo'] as String?,
    voteCount: integer(json['voteCount']),
    isLeading: json['isLeading'] as bool? ?? false,
    voters: list(json['voters'], MemberRef.fromJson),
  );

  final String id;
  final String label;
  final String? memo;
  final int voteCount;
  final bool isLeading;
  final List<MemberRef> voters;
}

class Poll {
  const Poll({
    required this.id,
    required this.title,
    required this.slotDate,
    required this.slotStart,
    required this.slotEnd,
    required this.deadlineAt,
    required this.status,
    required this.isVotingOpen,
    required this.creator,
    required this.canManage,
    required this.options,
    required this.voteCount,
    required this.memberCount,
    required this.myOptionId,
    required this.selectedOptionId,
    required this.scheduleId,
  });

  factory Poll.fromJson(Json json) => Poll(
    id: json['id'] as String,
    title: json['title'] as String,
    slotDate: date(json['slotDate']),
    slotStart: time(json['slotStart']),
    slotEnd: time(json['slotEnd']),
    deadlineAt: instantOrNull(json['deadlineAt']),
    status: enumOf(PollStatus.values, json['status'], PollStatus.open),
    isVotingOpen: json['isVotingOpen'] as bool? ?? false,
    creator: MemberRef.fromJson(json['creator'] as Json),
    canManage: json['canManage'] as bool? ?? false,
    options: list(json['options'], PollOption.fromJson),
    voteCount: integer(json['voteCount']),
    memberCount: integer(json['memberCount']),
    myOptionId: json['myOptionId'] as String?,
    selectedOptionId: json['selectedOptionId'] as String?,
    scheduleId: json['scheduleId'] as String?,
  );

  final String id;
  final String title;
  final DateTime slotDate;
  final TimeOfDay slotStart;
  final TimeOfDay slotEnd;
  final DateTime? deadlineAt;
  final PollStatus status;
  final bool isVotingOpen;
  final MemberRef creator;
  final bool canManage;
  final List<PollOption> options;
  final int voteCount;
  final int memberCount;
  final String? myOptionId;
  final String? selectedOptionId;
  final String? scheduleId;

  PollOption? get selectedOption {
    for (final option in options) {
      if (option.id == selectedOptionId) {
        return option;
      }
    }
    return null;
  }
}
