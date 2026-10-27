import '../data/trip_repository.dart';

abstract final class TripStrings {
  static const String previewAction = '새 여행 화면 미리보기';
  static const String previewNotice = '샘플 여행 · 서버에 저장되지 않아요';
  static const String title = '내 여행';
  static const String headline = '다음 여행을 함께 준비해요';
  static const String description = '여행을 만들거나 초대 코드로 참여하세요.';
  static const String create = '여행 만들기';
  static const String join = '코드로 참여';
  static const String name = '여행 이름';
  static const String destination = '여행지';
  static const String nameHint = '예: 친구들과 오사카 4박 5일';
  static const String destinationHint = '예: 일본 오사카';
  static const String period = '여행 기간';
  static const String currency = '여행 통화';
  static const String yen = '일본 엔 (JPY)';
  static const String won = '한국 원 (KRW)';
  static const String dollars = '미국 달러 (USD)';
  static const String euros = '유로 (EUR)';
  static const String empty = '아직 여행이 없어요';
  static const String emptyHint = '첫 여행을 만들고 친구들을 초대해 보세요.';
  static const String loadError = '여행 목록을 불러오지 못했어요.';
  static const String detailError = '여행 정보를 불러오지 못했어요.';
  static const String pendingApi =
      '여행 기능을 사용할 수 없어요. 서버 연결 상태를 확인한 후 다시 시도해 주세요.';
  static const String retry = '다시 시도';
  static const String logout = '로그아웃';
  static const String logoutConfirm = '로그아웃할까요?';
  static const String cancel = '취소';
  static const String busy = '처리 중…';
  static const String invalidName = '여행 이름을 1~50자로 입력해 주세요.';
  static const String invalidDestination = '여행지를 1~100자로 입력해 주세요.';
  static const String selectDates = '날짜 선택';
  static const String dateRequired = '여행 기간을 선택해 주세요.';
  static const String createHint = '함께 사용할 통화와 여행 기간을 정해 주세요.';
  static const String created = '여행을 만들었어요';
  static const String overview = '여행 정보';
  static const String invite = '초대 코드';
  static const String copyInvite = '초대 코드 복사';
  static const String copied = '초대 코드를 복사했어요.';
  static const String members = '함께하는 사람';
  static const String me = '나';
  static const String expenses = '이 여행의 경비 미리보기';
  static const String expenseHint =
      '이 여행의 멤버로 비용을 나눠 볼 수 있어요. 미리보기 지출은 앱을 닫으면 초기화돼요.';
  static const String unsupportedCurrency = '경비 미리보기는 현재 엔화·원화 여행을 지원해요.';
  static const String codeLabel = '초대 코드 8자리';
  static const String codeInvalid = '영문·숫자 8자리 코드를 입력해 주세요.';
  static const String joinHint = '친구에게 받은 코드를 입력하면 같은 여행에 참여할 수 있어요.';
  static const String failed = '요청을 처리하지 못했어요. 다시 시도해 주세요.';
  static String role(TripRole role) => switch (role) {
    TripRole.host => '방장',
    TripRole.member => '멤버',
    TripRole.guest => '게스트',
  };
  static String count(int count) => '$count명';
  static String range(String start, String end) =>
      '${start.replaceAll('-', '.')} ~ ${end.replaceAll('-', '.')}';
  static String dateParam(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String status(TripSummary trip) {
    final current = DateTime.now();
    final now = DateTime(current.year, current.month, current.day);
    final start = DateTime.parse(trip.startDate),
        end = DateTime.parse(trip.endDate);
    if (now.isAfter(end)) {
      return '다녀온 여행';
    }
    if (now.isBefore(start)) {
      return 'D-${start.difference(now).inDays}';
    }
    return '${now.difference(start).inDays + 1}일차';
  }
}
