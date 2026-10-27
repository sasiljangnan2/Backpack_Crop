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

  /// 필드 메시지가 있으면 그것을, 없으면 전체 메시지를 돌려준다.
  String get displayMessage {
    if (details.isEmpty) {
      return message;
    }
    return details.values.first;
  }

  @override
  String toString() => 'ApiException($status $code): $message $details';
}
