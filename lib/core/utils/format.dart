import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 화면에 보이는 숫자 · 날짜 형식을 한곳에 모은다.
abstract final class Fmt {
  static final _won = NumberFormat('#,##0', 'ko_KR');
  static final _decimal = NumberFormat('#,##0.##', 'ko_KR');

  /// ₩12,345
  static String krw(int amount) =>
      amount < 0 ? '-₩${_won.format(-amount)}' : '₩${_won.format(amount)}';

  /// +₩12,345 / -₩12,345 (0이면 ₩0)
  static String signedKrw(int amount) =>
      amount > 0 ? '+${krw(amount)}' : krw(amount);

  /// 통화 기호와 함께: ¥4,850 · $12.5 · €3
  static String money(double amount, String currencyCode) {
    final symbol = currencySymbols[currencyCode];
    final text = _decimal.format(amount);
    return symbol == null ? '$text $currencyCode' : '$symbol$text';
  }

  static String number(num value) => _decimal.format(value);

  static const currencySymbols = {
    'KRW': '₩',
    'JPY': '¥',
    'USD': r'$',
    'EUR': '€',
    'CNY': '¥',
    'GBP': '£',
    'THB': '฿',
    'VND': '₫',
    'TWD': r'NT$',
    'HKD': r'HK$',
    'SGD': r'S$',
    'PHP': '₱',
    'AUD': r'A$',
    'CAD': r'C$',
  };

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// 10.03 토
  static String shortDate(DateTime d) =>
      '${d.month}.${d.day.toString().padLeft(2, '0')} ${_weekdays[d.weekday - 1]}';

  /// 10.03
  static String monthDay(DateTime d) =>
      '${d.month}.${d.day.toString().padLeft(2, '0')}';

  /// 2026년 10월 3일 (토)
  static String longDate(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';

  /// 10.02 – 10.06
  static String range(DateTime start, DateTime end) =>
      '${monthDay(start)} – ${monthDay(end)}';

  /// 14:50
  static String time(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 2시간 40분 / 35분
  static String minutes(int total) {
    if (total < 60) {
      return '$total분';
    }
    final hours = total ~/ 60;
    final rest = total % 60;
    return rest == 0 ? '$hours시간' : '$hours시간 $rest분';
  }

  /// 방금 · 5분 전 · 3시간 전 · 10.03
  static String ago(DateTime at) {
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inMinutes < 1) {
      return '방금';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}분 전';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}시간 전';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    }
    return monthDay(at.toLocal());
  }

  /// D-3 / D-DAY / D+2
  static String dDay(int days) {
    if (days == 0) {
      return 'D-DAY';
    }
    return days > 0 ? 'D-$days' : 'D+${-days}';
  }
}

int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

TimeOfDay timeOfMinutes(int minutes) =>
    TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
