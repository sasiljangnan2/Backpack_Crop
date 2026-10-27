import 'package:flutter/material.dart';

import '../../../core/network/json.dart';
import '../../place/data/place_models.dart';

/// BP-AI-002 조건 칩
enum ReplanCondition {
  walk15('도보 15분 이내', 'WALK_15'),
  rest('휴식 필요', 'REST'),
  indoor('실내 위주', 'INDOOR'),
  food('먹거리 포함', 'FOOD');

  const ReplanCondition(this.label, this.code);

  final String label;
  final String code;
}

/// BP-AI-003 추천 3안의 기준
enum PlanKey {
  condition('CONDITION'),
  minTravel('MIN_TRAVEL'),
  slack('SLACK');

  const PlanKey(this.code);

  final String code;
}

/// AI: Gemini가 고른 안 · RULE: 규칙 기반 추천 (AI 키가 없거나 실패했을 때)
enum ReplanSource { ai, rule }

class ReplanAnchor {
  const ReplanAnchor({
    required this.scheduleId,
    required this.title,
    required this.placeText,
    required this.startTime,
    required this.isLocked,
    required this.minutesUntil,
  });

  factory ReplanAnchor.fromJson(Json json) => ReplanAnchor(
    scheduleId: json['scheduleId'] as String,
    title: json['title'] as String,
    placeText: json['placeText'] as String?,
    startTime: time(json['startTime']),
    isLocked: json['isLocked'] as bool? ?? false,
    minutesUntil: integer(json['minutesUntil']),
  );

  final String scheduleId;
  final String title;
  final String? placeText;
  final TimeOfDay startTime;
  final bool isLocked;
  final int minutesUntil;
}

/// "AI가 읽은 현재 상황"
class ReplanContext {
  const ReplanContext({
    required this.currentPlace,
    required this.currentPlaceFromGps,
    required this.now,
    required this.windowStart,
    required this.windowEnd,
    required this.doneCount,
    required this.delayMin,
    required this.anchor,
  });

  factory ReplanContext.fromJson(Json json) => ReplanContext(
    currentPlace: json['currentPlace'] as String?,
    currentPlaceFromGps: json['currentPlaceFromGps'] as bool? ?? false,
    now: time(json['now']),
    windowStart: time(json['windowStart']),
    windowEnd: time(json['windowEnd']),
    doneCount: integer(json['doneCount']),
    delayMin: integer(json['delayMin']),
    anchor: json['anchor'] == null
        ? null
        : ReplanAnchor.fromJson(json['anchor'] as Json),
  );

  final String? currentPlace;
  final bool currentPlaceFromGps;
  final TimeOfDay now;
  final TimeOfDay windowStart;
  final TimeOfDay windowEnd;
  final int doneCount;
  final int delayMin;
  final ReplanAnchor? anchor;
}

class PlanItem {
  const PlanItem({
    required this.scheduleId,
    required this.title,
    required this.placeText,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.stayMin,
    required this.travelBefore,
    required this.isNew,
  });

  factory PlanItem.fromJson(Json json) => PlanItem(
    scheduleId: json['scheduleId'] as String?,
    title: json['title'] as String,
    placeText: json['placeText'] as String?,
    category: json['category'] == null
        ? null
        : enumOf(PlaceCategory.values, json['category'], PlaceCategory.etc),
    startTime: time(json['startTime']),
    endTime: time(json['endTime']),
    stayMin: integer(json['stayMin']),
    travelBefore: TravelLeg.fromJson(json['travelBefore'] as Json),
    isNew: json['isNew'] as bool? ?? false,
  );

  /// null이면 새로 넣는 일정 (휴식 · AI가 추천한 장소)
  final String? scheduleId;
  final String title;
  final String? placeText;
  final PlaceCategory? category;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int stayMin;
  final TravelLeg travelBefore;
  final bool isNew;
}

class ReplanPlan {
  const ReplanPlan({
    required this.key,
    required this.label,
    required this.reason,
    required this.startTime,
    required this.endTime,
    required this.travelMin,
    required this.slackMin,
    required this.conditionRate,
    required this.items,
    required this.travelToAnchor,
    required this.dropped,
  });

  factory ReplanPlan.fromJson(Json json) => ReplanPlan(
    key: enumOf(PlanKey.values, json['key'], PlanKey.condition),
    label: json['label'] as String,
    reason: json['reason'] as String? ?? '',
    startTime: time(json['startTime']),
    endTime: time(json['endTime']),
    travelMin: integer(json['travelMin']),
    slackMin: integerOrNull(json['slackMin']),
    conditionRate: integer(json['conditionRate']),
    items: list(json['items'], PlanItem.fromJson),
    travelToAnchor: json['travelToAnchor'] == null
        ? null
        : TravelLeg.fromJson(json['travelToAnchor'] as Json),
    dropped: [
      for (final d in (json['dropped'] as List? ?? const []))
        (id: (d as Json)['scheduleId'] as String, title: d['title'] as String),
    ],
  );

  final PlanKey key;
  final String label;
  final String reason;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int travelMin;
  final int? slackMin;
  final int conditionRate;
  final List<PlanItem> items;
  final TravelLeg? travelToAnchor;

  /// 이 안을 적용하면 빠지는(지워지는) 일정
  final List<({String id, String title})> dropped;
}

class ReplanResult {
  const ReplanResult({
    required this.requestId,
    required this.source,
    required this.notice,
    required this.context,
    required this.plans,
  });

  factory ReplanResult.fromJson(Json json) => ReplanResult(
    requestId: json['requestId'] as String,
    source: enumOf(ReplanSource.values, json['source'], ReplanSource.rule),
    notice: json['notice'] as String?,
    context: ReplanContext.fromJson(json['context'] as Json),
    plans: list(json['plans'], ReplanPlan.fromJson),
  );

  final String requestId;
  final ReplanSource source;
  final String? notice;
  final ReplanContext context;
  final List<ReplanPlan> plans;
}
