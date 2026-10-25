import '../data/expense_request.dart';

class ExpenseSplitStrings {
  const ExpenseSplitStrings._();
  static const String helpTitle = '먹은 만큼, 정확하게 나눠요';
  static const String helpBody =
      '항목마다 비용을 나눌 사람을 선택하세요. 같은 항목의 금액은 선택한 사람끼리 균등하게 나눠요.\n\n모두 똑같이 부담하려면 균등 분담을 선택하세요. 항목별 선택은 다시 돌아와도 유지돼요.\n\n입력한 금액으로 나눠 보는 샘플 화면이에요. 목록에 반영해도 앱을 닫으면 초기화돼요.';
  static const String resultTitle = '개인별 부담';
  static const String payer = '결제자';
  static const String totalShare = '부담액 합계';
  static const String resultNote =
      '원 단위 끝전은 결제자 우선으로 조정해 합계를 맞춰요.\n입력한 금액과 환율로 계산한 샘플 미리보기예요.';
  static const String copied = '분담 결과를 복사했어요.';
  static const String copy = '분담 결과 복사';
  static const String title = '분담 정하기';
  static const String back = '뒤로';
  static const String help = '분담 방법 안내';
  static const String sample = '샘플 지출';
  static const String equal = '균등 분담';
  static const String item = '항목별 분담';
  static const String choosePeople = '이 항목을 함께 나눌 사람은?';
  static const String equalHint = '선택한 항목과 관계없이 전체 금액을 나눠요.';
  static const String itemHint = '이름을 눌러 참여자를 선택하거나 해제하세요.';
  static const String roundingHint =
      '같은 항목은 선택한 사람끼리 균등하게 나눠요.\n원화 환산 후 원 단위 끝전을 조정해 전체 합계를 맞춰요.';
  static const String confirm = '분담 결과 확인';
  static const String selectMember = '참여자를 1명 이상 선택해 주세요.';

  static String tripCategory(String tripName, ExpenseCategory category) {
    final label = switch (category) {
      ExpenseCategory.food => '식비',
      ExpenseCategory.lodging => '숙박',
      ExpenseCategory.transport => '교통',
      ExpenseCategory.activity => '활동',
      ExpenseCategory.shopping => '쇼핑',
      ExpenseCategory.etc => '기타',
    };
    return '$tripName · $label';
  }

  static const String loadError = '경비 정보를 불러오지 못했어요.';
  static const String retry = '다시 시도';

  static String money(num amount) {
    final text = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    final parts = text.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return parts.length == 1 ? whole : '$whole.${parts.last}';
  }

  static String amount(num value, String currencyCode) =>
      currencyCode == 'KRW' ? '₩${money(value)}' : yen(value);

  static String yen(num amount) => amount == amount.roundToDouble()
      ? '¥${money(amount)}'
      : '약 ¥${money(amount)}';
  static String approximateWon(int amount) => '약 ₩${money(amount)}';
  static String sampleRate(num rate, [String currencyCode = 'JPY']) =>
      currencyCode == 'KRW'
      ? '원화로 입력한 금액'
      : '입력 환율 · 100엔 = ${money(rate * 100)}원';
  static String copyRate(num rate, [String currencyCode = 'JPY']) =>
      '${sampleRate(rate, currencyCode)} · 샘플 미리보기';
  static String equalPeople(int count) => '$count명이 똑같이 나눠요';
  static String missingPeople(int count) => '참여자를 선택하지 않은 항목이 $count개 있어요.';
  static String payerShare(String name) => '$name의 부담';
  static String perPerson(
    int count,
    num amount, [
    String currencyCode = 'JPY',
  ]) => '$count명 · 1인 ${ExpenseSplitStrings.amount(amount, currencyCode)}';
  static String adjustment(int amount) => '끝전 ${amount > 0 ? '+' : ''}$amount원';
  static String resultSubtitle(String title, bool isEqual) =>
      '$title · ${isEqual ? equal : item}';
  static String copyTotal(num local, int won, [String currencyCode = 'JPY']) =>
      '합계 ${amount(local, currencyCode)} / ₩${money(won)}';
}
