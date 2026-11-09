import 'package:flutter/material.dart';

import '../../../core/network/json.dart';
import '../../../core/utils/format.dart';

/// 장소 분류 (OpenStreetMap 태그에서 서버가 정한다). 일정 재구성 조건에 쓴다
enum PlaceCategory {
  food('맛집', Icons.restaurant),
  cafe('카페', Icons.local_cafe_outlined),
  shopping('쇼핑', Icons.shopping_bag_outlined),
  sight('관광', Icons.photo_camera_outlined),
  park('공원', Icons.park_outlined),
  lodging('숙소', Icons.hotel_outlined),
  transport('교통', Icons.train_outlined),
  etc('기타', Icons.place_outlined);

  const PlaceCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 장소 검색 · 현재 위치 결과
class Place {
  const Place({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
    this.fromGoogle = false,
  });

  factory Place.fromJson(Json json) => Place(
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    lat: decimal(json['lat']),
    lng: decimal(json['lng']),
    category: enumOf(PlaceCategory.values, json['category'], PlaceCategory.etc),
    fromGoogle: json['source'] == 'GOOGLE',
  );

  final String name;
  final String address;
  final double lat;
  final double lng;
  final PlaceCategory category;

  /// Google Places 결과 (아니면 OpenStreetMap). 검색 결과 밑의 출처 표시에 쓴다
  final bool fromGoogle;
}

enum TravelMode { walk, transit, drive }

/// 두 장소 사이 이동. 걸어서 20분 이내면 도보, 아니면 대중교통(구글 경로가 있을 때), 없으면 차(어림값)
class TravelLeg {
  const TravelLeg({
    required this.mode,
    required this.minutes,
    required this.distanceM,
    required this.walkMin,
    required this.driveMin,
    this.transitMin,
    required this.estimated,
  });

  factory TravelLeg.fromJson(Json json) => TravelLeg(
    mode: enumOf(TravelMode.values, json['mode'], TravelMode.walk),
    minutes: integer(json['minutes']),
    distanceM: integer(json['distanceM']),
    walkMin: integer(json['walkMin']),
    driveMin: integer(json['driveMin']),
    transitMin: integerOrNull(json['transitMin']),
    estimated: json['estimated'] as bool? ?? false,
  );

  final TravelMode mode;
  final int minutes;
  final int distanceM;
  final int walkMin;
  final int driveMin;
  final int? transitMin;

  /// 경로 서버에 닿지 못해 직선거리로 어림한 값
  final bool estimated;

  IconData get icon => switch (mode) {
    TravelMode.walk => Icons.directions_walk,
    TravelMode.transit => Icons.directions_subway_outlined,
    TravelMode.drive => Icons.directions_car_outlined,
  };

  /// "도보 8분 · 650m", "대중교통 15분 · 4.1km", "차로 약 15분 · 4.1km" (차 시간은 늘 어림값)
  String get label {
    final how = switch (mode) {
      TravelMode.walk => '도보',
      TravelMode.transit => '대중교통',
      TravelMode.drive => '차로',
    };
    final about = estimated || mode == TravelMode.drive ? '약 ' : '';
    return '$how $about${Fmt.minutes(minutes)} · ${Fmt.distance(distanceM)}';
  }
}

class RouteLeg {
  const RouteLeg({
    required this.fromScheduleId,
    required this.toScheduleId,
    required this.travel,
  });

  factory RouteLeg.fromJson(Json json) => RouteLeg(
    fromScheduleId: json['fromScheduleId'] as String,
    toScheduleId: json['toScheduleId'] as String,
    travel: TravelLeg.fromJson(json['travel'] as Json),
  );

  final String fromScheduleId;
  final String toScheduleId;
  final TravelLeg travel;
}

/// 그날 동선: 좌표가 있는 일정끼리 시간 순서대로 이은 이동
class DayRoute {
  const DayRoute({
    required this.legs,
    required this.totalDistanceM,
    required this.totalMin,
    required this.placedCount,
    required this.missingPlaceCount,
  });

  factory DayRoute.fromJson(Json json) => DayRoute(
    legs: list(json['legs'], RouteLeg.fromJson),
    totalDistanceM: integer(json['totalDistanceM']),
    totalMin: integer(json['totalMin']),
    placedCount: integer(json['placedCount']),
    missingPlaceCount: integer(json['missingPlaceCount']),
  );

  static const empty = DayRoute(
    legs: [],
    totalDistanceM: 0,
    totalMin: 0,
    placedCount: 0,
    missingPlaceCount: 0,
  );

  final List<RouteLeg> legs;
  final int totalDistanceM;
  final int totalMin;
  final int placedCount;
  final int missingPlaceCount;

  /// [scheduleId]에서 바로 다음 일정으로 가는 이동
  RouteLeg? legFrom(String scheduleId) {
    for (final leg in legs) {
      if (leg.fromScheduleId == scheduleId) {
        return leg;
      }
    }
    return null;
  }

  /// "총 이동 약 14.7km · 1시간 15분"
  String get summary =>
      '총 이동 ${Fmt.distance(totalDistanceM)} · ${Fmt.minutes(totalMin)}';
}
