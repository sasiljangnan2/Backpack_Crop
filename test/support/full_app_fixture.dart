import 'dart:convert';

import 'package:http/http.dart' as http;

class FullAppFixture {
  final requests = <http.Request>[];
  final unexpected = <String>[];
  final schedules = <Map<String, Object?>>[
    {
      'id': 's1',
      'day': '2026-11-10',
      'startTime': '13:30',
      'endTime': '14:30',
      'title': '구로몬 시장',
      'placeText': '난바',
      'isLocked': false,
      'reservationStatus': 'NONE',
      'status': 'PLANNED',
      'createdBy': {'memberId': 'm1', 'name': '준휘'},
      'version': 0,
    },
  ];
  static const me = {'memberId': 'm1', 'name': '준휘'};
  static const other = {'memberId': 'm2', 'name': '성진'};
  static const trip = {
    'id': 't1',
    'name': '오사카 4박 5일',
    'destination': '오사카, 일본',
    'startDate': '2026-11-09',
    'endDate': '2026-11-13',
    'nights': 4,
    'currencyCode': 'JPY',
    'timeZone': 'Asia/Tokyo',
    'inviteCode': 'OSAKA026',
    'status': 'LIVE',
    'dDay': -1,
    'dayNo': 2,
    'myMemberId': 'm1',
    'myRole': 'HOST',
    'members': [
      {'memberId': 'm1', 'name': '준휘', 'role': 'HOST', 'isMe': true},
      {'memberId': 'm2', 'name': '성진', 'role': 'MEMBER', 'isMe': false},
    ],
  };
  static const expenses = [
    {
      'id': 'e1',
      'title': '이치란 라멘 난바점',
      'category': 'FOOD',
      'paidDate': '2026-11-10',
      'rateMode': 'MANUAL',
      'amountLocal': 7360,
      'amountKrw': 68816,
      'payer': other,
      'creator': other,
      'isPaidByMe': false,
      'myShareKrw': 14305,
    },
    {
      'id': 'e2',
      'title': '우메다 스카이빌딩 입장권',
      'category': 'ACTIVITY',
      'paidDate': '2026-11-09',
      'rateMode': 'MANUAL',
      'amountLocal': 10000,
      'amountKrw': 93500,
      'payer': me,
      'creator': me,
      'isPaidByMe': true,
      'myShareKrw': 18700,
    },
  ];
  static const budget = {
    'items': [],
    'summary': [],
    'totalBudgetKrw': 2000000,
    'totalSpentKrw': 162316,
    'memberCount': 2,
    'perPersonBudgetKrw': 1000000,
    'currencyCode': 'JPY',
    'todayRate': null,
    'hasUnconvertedItems': false,
  };
  static const mine = {
    'me': me,
    'paidKrw': 93500,
    'shareKrw': 33005,
    'balanceKrw': 60495,
    'status': 'RECEIVE',
    'tripTotalKrw': 162316,
    'expenseCount': 2,
    'transfers': [
      {'direction': 'RECEIVE', 'counterpart': other, 'amountKrw': 60495},
    ],
    'expenses': [],
  };
  static const settlement = {
    'totalKrw': 162316,
    'expenseCount': 2,
    'transferTotalKrw': 60495,
    'directTransferCount': 1,
    'members': [
      {
        'memberId': 'm1',
        'name': '준휘',
        'isMe': true,
        'paidKrw': 93500,
        'shareKrw': 33005,
        'balanceKrw': 60495,
        'status': 'RECEIVE',
      },
      {
        'memberId': 'm2',
        'name': '성진',
        'isMe': false,
        'paidKrw': 68816,
        'shareKrw': 129311,
        'balanceKrw': -60495,
        'status': 'SEND',
      },
    ],
    'transfers': [
      {'from': other, 'to': me, 'amountKrw': 60495},
    ],
  };

  http.Response reply(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/replan/apply')) {
      schedules[0] = {
        ...schedules.first,
        'title': '난바 카페에서 휴식',
        'replanned': true,
        'version': 1,
      };
      return reply(schedules);
    }
    if (path.endsWith('/replan')) {
      return reply({
        'requestId': 'plan1',
        'source': 'RULE',
        'notice': '테스트 서버의 추천안',
        'context': {
          'currentPlace': '난바',
          'now': '12:00',
          'windowStart': '12:00',
          'windowEnd': '18:00',
          'doneCount': 0,
          'delayMin': 0,
        },
        'plans': [
          for (final key in ['CONDITION', 'MIN_TRAVEL', 'SLACK'])
            {
              'key': key,
              'label': key == 'CONDITION'
                  ? '조건을 반영한 일정'
                  : key == 'MIN_TRAVEL'
                  ? '이동을 줄인 일정'
                  : '여유 있는 일정',
              'reason': '고정 일정을 유지하고 휴식 시간을 확보해요.',
              'startTime': '13:30',
              'endTime': '14:30',
              'travelMin': 0,
              'slackMin': 210,
              'conditionRate': 100,
              'items': [
                {
                  'scheduleId': 's1',
                  'title': '난바 카페에서 휴식',
                  'placeText': '난바',
                  'startTime': '13:30',
                  'endTime': '14:30',
                  'stayMin': 60,
                  'travelBefore': {
                    'mode': 'WALK',
                    'minutes': 0,
                    'distanceM': 0,
                    'walkMin': 0,
                    'driveMin': 0,
                  },
                },
              ],
            },
        ],
      });
    }
    if (path == '/api/trips/t1') return reply(trip);
    if (path == '/api/notifications/unread-count') return reply({'count': 0});
    if (path.endsWith('/budget-items')) return reply(budget);
    if (path.endsWith('/settlement/me')) return reply(mine);
    if (path.endsWith('/settlement')) return reply(settlement);
    if (path.endsWith('/settlement-shares') ||
        path.endsWith('/polls') ||
        path.endsWith('/tasks')) {
      return reply([]);
    }
    if (path.endsWith('/today')) {
      return reply({
        'date': '2026-11-10',
        'localTime': '12:00',
        'tripStatus': 'LIVE',
        'dayNo': 2,
        'current': null,
        'next': schedules.first,
        'nextFixed': null,
        'delayMin': 0,
        'doneCount': 0,
        'total': schedules.length,
        'remaining': schedules.length,
        'schedules': schedules,
      });
    }
    if (path.endsWith('/schedules/route')) {
      return reply({
        'legs': [],
        'totalDistanceM': 0,
        'totalMin': 0,
        'placedCount': 0,
        'missingPlaceCount': schedules.length,
      });
    }
    if (path.endsWith('/schedules')) {
      if (request.method == 'POST') {
        final value = jsonDecode(request.body) as Map<String, dynamic>;
        schedules.add({
          ...value,
          'id': 's2',
          'status': 'PLANNED',
          'createdBy': me,
          'version': 0,
        });
        return reply(schedules.last, 201);
      }
      return reply(schedules);
    }
    if (path.endsWith('/expenses')) {
      final category = request.url.queryParameters['category'];
      final items = expenses
          .where((e) => category == null || e['category'] == category)
          .toList();
      return reply({
        'content': items,
        'nextCursor': null,
        'hasNext': false,
        'summary': {
          'count': items.length,
          'totalKrw': items.fold<int>(
            0,
            (sum, e) => sum + (e['amountKrw'] as int),
          ),
          'byCategory': [
            {'category': 'FOOD', 'amountKrw': 68816},
            {'category': 'ACTIVITY', 'amountKrw': 93500},
          ],
        },
      });
    }
    unexpected.add('${request.method} $path');
    return reply({
      'code': 'NOT_FOUND',
      'message': 'Unexpected test request',
    }, 404);
  }
}
