import 'package:flutter/material.dart';

/// 서버 JSON을 화면 모델로 바꿀 때 쓰는 도우미.
///
/// - 시각(`2026-10-12T03:00:00Z`)은 [instant]로 읽고 화면에서는 `.toLocal()`로 보여 준다.
/// - 날짜(`2026-10-12`)는 시간대 변환 없이 [date]로 읽는다.
/// - 시간(`14:50`)은 [time]으로 읽는다.
typedef Json = Map<String, dynamic>;

DateTime instant(Object? value) => DateTime.parse(value as String);

DateTime? instantOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

DateTime date(Object? value) {
  final parts = (value as String).split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// 필드 이름이 date인 모델에서 쓰는 별칭 (같은 이름의 필드가 함수를 가린다)
DateTime parseDate(Object? value) => date(value);

DateTime? dateOrNull(Object? value) => value == null ? null : date(value);

TimeOfDay time(Object? value) {
  final parts = (value as String).split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

int integer(Object? value) => (value as num).toInt();

int? integerOrNull(Object? value) => value == null ? null : integer(value);

double decimal(Object? value) => (value as num).toDouble();

double? decimalOrNull(Object? value) => value == null ? null : decimal(value);

List<T> list<T>(Object? value, T Function(Json json) parse) => [
  for (final item in (value as List<dynamic>? ?? const [])) parse(item as Json),
];

/// 서버로 보낼 날짜: `yyyy-MM-dd` (시간대 변환 금지)
String dateParam(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// 서버로 보낼 시간: `HH:mm`
String timeParam(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

/// enum 이름(`EXPENSE_ADDED`)을 Dart enum으로. 모르는 값이면 [fallback]
T enumOf<T extends Enum>(List<T> values, Object? name, T fallback) {
  final normalized = (name as String?)?.replaceAll('_', '').toLowerCase();
  for (final value in values) {
    if (value.name.toLowerCase() == normalized) {
      return value;
    }
  }
  return fallback;
}

/// Dart enum(`expenseAdded`)을 서버 이름(`EXPENSE_ADDED`)으로
String enumName(Enum value) => value.name
    .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
    .toUpperCase();
