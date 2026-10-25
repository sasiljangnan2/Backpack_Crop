import '../data/expense_request.dart';
import 'expense_split_strings.dart';

abstract final class ExpenseStrings {
  static const String title = '경비';
  static const String total = '여행 공동 지출';
  static const String myShare = '내 부담액';
  static const String all = '전체';
  static const String add = '지출 추가';
  static const String edit = '지출 수정';
  static const String detail = '지출 상세';
  static const String sample = '샘플 · 앱을 닫으면 초기화돼요';
  static const String empty = '등록된 지출이 없어요';
  static const String emptyHint = '여행에서 쓴 비용을 첫 번째로 기록해 보세요.';
  static const String filterEmpty = '이 카테고리의 지출이 없어요';
  static const String loadError = '지출 목록을 불러오지 못했어요.';
  static const String saveError = '등록하지 못했어요. 입력 내용은 유지돼요. 다시 시도해 주세요.';
  static const String retry = '다시 시도';
  static const String saved = '샘플 목록에 지출을 등록했어요.';
  static const String updated = '샘플 지출을 수정했어요.';
  static const String titleLabel = '지출명';
  static const String titleHint = '예: 이치란 라멘 점심';
  static const String date = '결제 날짜';
  static const String category = '카테고리';
  static const String payer = '결제자';
  static const String currency = '통화';
  static const String yen = '일본 엔 (JPY)';
  static const String won = '한국 원 (KRW)';
  static const String rate = '1엔당 원화 환율';
  static const String rateHint = '직접 입력한 환율로 미리 계산해요.';
  static const String items = '지출 항목';
  static const String itemName = '항목명';
  static const String itemAmount = '항목 전체 금액';
  static const String addItem = '항목 추가';
  static const String removeItem = '항목 삭제';
  static const String next = '다음: 분담 정하기';
  static const String saving = '등록 중…';
  static const String confirmSplit = '이 분담으로 적용';
  static const String savedSummary = '분담 내역';
  static const String titleRequired = '지출명을 입력해 주세요.';
  static const String itemRequired = '항목명을 입력해 주세요.';
  static const String nameTooLong = '100자 이내로 입력해 주세요.';
  static const String amountInvalid = '0보다 크고 1억 이하인 금액을 입력해 주세요.';
  static const String decimalInvalid = '외화는 소수 둘째 자리까지 입력해 주세요.';
  static const String wonInvalid = '원화는 정수로 입력해 주세요.';
  static const String rateInvalid = '환율은 0보다 크고 100만 이하로 입력해 주세요.';
  static const String ratePrecision = '환율은 소수 여섯째 자리까지 입력해 주세요.';
  static const String formHint = '항목 금액은 수량을 포함한 전체 금액으로 입력하세요.';
  static const String unsavedTitle = '입력한 내용을 나갈까요?';
  static const String unsavedBody = '작성 중인 지출은 목록에 등록되지 않아요.';
  static const String stay = '계속 작성';
  static const String leave = '나가기';
  static const String totalLabel = '지출 합계';

  static String categoryLabel(ExpenseCategory value) => switch (value) {
    ExpenseCategory.food => '식비',
    ExpenseCategory.lodging => '숙박',
    ExpenseCategory.transport => '교통',
    ExpenseCategory.activity => '활동',
    ExpenseCategory.shopping => '쇼핑',
    ExpenseCategory.etc => '기타',
  };
  static String krw(num value) => '₩${ExpenseSplitStrings.money(value)}';
  static String dateLabel(String date) => date.replaceAll('-', '.');
  static String dateGroup(String date) =>
      '${int.parse(date.substring(5, 7))}월 ${int.parse(date.substring(8, 10))}일';
  static String payerLabel(String name) => '$name 결제';
  static String itemIndex(int index) => '항목 ${index + 1}';
  static String memberCount(int count) => '$count명 분담';
  static String budget(int amount) => '전체 예산 ${krw(amount)}';
  static String itemPeople(Iterable<String> names) => names.join(' · ');
}
