import '../data/schedule_models.dart';

abstract final class ScheduleStrings {
  static const String validationHint = '이름과 날짜, 시간을 확인해 주세요.';
  static const String latestAction = '최신 일정 확인';
  static const String loadingLatest = '확인 중…';
  static const String latestTitle = '서버의 최신 일정';
  static const String latestHint = '불러오면 작성 중인 내용을 최신 일정으로 바꿔요.';
  static const String latestLoad = '최신 내용 불러오기';
  static const String latestMissing = '이 일정이 삭제됐어요. 작성 중인 내용은 이 화면에 유지돼요.';
  static const String title = '여행 일정';
  static const String open = '여행 일정 보기';
  static const String add = '일정 추가';
  static const String edit = '일정 수정';
  static const String save = '일정 저장';
  static const String saving = '저장 중…';
  static const String empty = '아직 일정이 없어요';
  static const String emptyHint = '아래 일정 추가 버튼으로 하루를 채워 보세요.';
  static const String preview = '샘플 일정 · 앱을 닫으면 초기화돼요';
  static const String readOnly = '게스트는 일정을 확인할 수만 있어요.';
  static const String name = '어떤 일정인가요?';
  static const String nameHint = '예: 오사카성 산책';
  static const String place = '장소 (선택)';
  static const String date = '날짜';
  static const String start = '시작 시간';
  static const String end = '종료 시간';
  static const String more = '추가 옵션';
  static const String moreHint = '예약 상태와 메모';
  static const String reservation = '예약 상태';
  static const String memo = '메모 (선택)';
  static const String nameError = '일정 이름을 1~100자로 입력해 주세요.';
  static const String placeError = '장소는 100자 이내로 입력해 주세요.';
  static const String memoError = '메모는 500자 이내로 입력해 주세요.';
  static const String timeError = '종료 시간은 시작 시간보다 늦어야 해요.';
  static const String overlapTitle = '시간이 겹치는 일정이 있어요';
  static const String overlapHint = '기존 일정과 시간을 확인한 뒤 저장해 주세요.';
  static const String overlapSave = '겹쳐도 저장';
  static const String cancel = '취소';
  static const String discardTitle = '작성 중인 일정을 나갈까요?';
  static const String discardHint = '저장하지 않은 내용은 사라져요.';
  static const String keepEditing = '계속 작성';
  static const String leave = '나가기';
  static const String saved = '일정을 추가했어요.';
  static const String updated = '일정을 수정했어요.';
  static const String deleted = '일정을 삭제했어요.';
  static const String delete = '일정 삭제';
  static const String deleteTitle = '이 일정을 삭제할까요?';
  static const String lock = '일정 고정';
  static const String unlock = '고정 해제';
  static const String locked = '고정';
  static const String lockedHint = '고정한 일정은 해제한 뒤 수정하거나 삭제할 수 있어요.';
  static const String lockDone = '일정을 고정했어요.';
  static const String unlockDone = '고정을 해제했어요.';
  static const String loadError = '일정을 불러오지 못했어요.';
  static const String saveError = '저장하지 못했어요. 입력 내용을 확인한 뒤 다시 시도해 주세요.';
  static const String conflict =
      '다른 사람이 수정했거나 고정한 일정이에요. 최신 목록을 확인해 주세요. 입력 내용은 이 화면에 유지돼요.';
  static const String retry = '다시 불러오기';
  static const String back = '뒤로';
  static const String noMemo = '작성한 메모가 없어요.';
  static const String author = '작성자';

  static String reservationLabel(ReservationStatus value) => switch (value) {
    ReservationStatus.none => '예약 없음',
    ReservationStatus.pending => '예약 대기',
    ReservationStatus.confirmed => '예약 확정',
  };
  static String dayLabel(int index) => '${index + 1}일차';
  static String dateLabel(String day) {
    final date = scheduleDate(day);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
  }

  static String shortDate(String day) => day.substring(5).replaceAll('-', '.');
  static String duration(int value) {
    final hours = value ~/ 60, minutes = value % 60;
    return hours == 0
        ? '$minutes분'
        : minutes == 0
        ? '$hours시간'
        : '$hours시간 $minutes분';
  }

  static String summary(int count, int minutes) =>
      '$count개 일정 · ${duration(minutes)}';
  static String timeRange(ScheduleRecord item) =>
      '${item.startTime} – ${item.endTime}';
  static String dateSemantics(String day, int index) =>
      '${dayLabel(index)}, ${dateLabel(day)}';
}
