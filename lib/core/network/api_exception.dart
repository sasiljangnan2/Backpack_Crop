/// 서버의 `ErrorResponse`(또는 네트워크 오류)를 담는다.
///
/// 화면은 [code]로 분기하고, [message]는 그대로 보여 줘도 된다.
/// [details]는 필드별 메시지다 (예: `{'email': '이메일 형식이 올바르지 않아요.'}`).
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.details = const {},
  });

  const ApiException.network()
    : status = 0,
      code = 'NETWORK',
      message = '인터넷 연결을 확인해 주세요.',
      details = const {};

  const ApiException.timeout()
    : status = 0,
      code = 'TIMEOUT',
      message = '서버 응답이 늦어요. 잠시 후 다시 시도해 주세요.',
      details = const {};

  final int status;
  final String code;
  final String message;
  final Map<String, String> details;

  bool get isNetworkError => status == 0;

  /// details에 사람이 읽을 문장이 아니라 값(일정 id · 버전 · 개수 · 입력한 코드)을 담아 오는 오류.
  /// 이 값을 그대로 보여 주면 안 되므로 전체 메시지를 쓴다
  /// (`REPLAN_INVALID_TARGET`은 details가 대부분 구체적인 안내 문장이라 넣지 않는다)
  static const _dataDetailCodes = {
    'SCHEDULE_LOCKED',
    'VERSION_CONFLICT',
    'TRIP_PERIOD_CONFLICT',
    'INVITE_CODE_NOT_FOUND',
    'EXCHANGE_RATE_NOT_FOUND',
  };

  /// 필드 메시지가 있으면 그것을, 없으면 전체 메시지를 돌려준다.
  ///
  /// 일정 겹침(`SCHEDULE_OVERLAP`)은 details에 메시지가 아니라 겹친 일정 정보
  /// (scheduleId · title · startTime · endTime)를 담아 오므로 그것으로 문장을 만든다.
  String get displayMessage {
    if (code == 'SCHEDULE_OVERLAP') {
      final title = details['title'];
      if (title == null) {
        return message;
      }
      final start = details['startTime'];
      final end = details['endTime'];
      final when = start != null && end != null ? '($start–$end) ' : '';
      return "그 시간에 '$title' $when일정이 있어요. 시간을 바꾸거나 그 일정을 먼저 옮겨 주세요.";
    }
    if (details.isEmpty || _dataDetailCodes.contains(code)) {
      return message;
    }
    return details.values.first;
  }

  @override
  String toString() => 'ApiException($status $code): $message $details';
}
