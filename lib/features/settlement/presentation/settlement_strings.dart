abstract final class SettlementStrings {
  static const String title = '정산 결과';
  static const String open = '정산 결과 보기';
  static const String previewOpen = '정산 미리보기';
  static const String preview = '미리보기 · 샘플 지출로 계산한 금액이에요.';
  static const String previewHint = '지출을 추가하거나 수정하면 정산에도 반영돼요. 앱을 닫으면 초기화돼요.';
  static const String total = '여행 전체 지출';
  static const String mySettlement = '내 정산';
  static const String paid = '낸 금액';
  static const String share = '부담할 금액';
  static const String receive = '받을 돈';
  static const String send = '보낼 돈';
  static const String balanced = '추가 송금 없음';
  static const String balanceHint = '낸 금액에서 부담할 금액을 뺀 결과예요.';
  static const String missingMe = '내 정산 정보가 없어요. 전체 멤버 내역을 확인해 주세요.';
  static const String transfers = '송금 안내';
  static const String mine = '내 송금';
  static const String all = '전체 송금';
  static const String members = '멤버별 정산';
  static const String memberHint = '멤버를 누르면 상세 내역을 볼 수 있어요.';
  static const String me = '나';
  static const String paymentHint = '금액과 받는 사람을 확인한 뒤 별도로 송금해 주세요.';
  static const String previewPaymentHint = '샘플 계산 결과이며 실제 송금은 진행되지 않아요.';
  static const String empty = '아직 등록된 지출이 없어요';
  static const String emptyHint = '지출을 등록하면 멤버별 부담액과 송금 안내가 표시돼요.';
  static const String noTransfers = '추가로 보낼 돈이 없어요';
  static const String noTransfersHint = '등록된 지출 기준으로 서로 정산할 차액이 없어요.';
  static const String noMyTransfers = '내가 주고받을 송금이 없어요';
  static const String noMyTransfersHint = '전체 송금에서 다른 멤버의 내역을 확인할 수 있어요.';
  static const String viewExpenses = '지출 내역 보기';
  static const String refresh = '새로고침';
  static const String retry = '다시 불러오기';
  static const String loadError = '정산 결과를 불러오지 못했어요.';
  static const String invalidData = '정산 금액을 확인할 수 없어요. 다시 불러오거나 담당자에게 확인해 주세요.';
  static const String stale = '새로 불러오지 못해 이전 조회 결과를 표시하고 있어요.';
  static const String close = '닫기';
  static String krw(int value) {
    final digits = value.abs().toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '${value < 0 ? '−' : ''}$grouped원';
  }

  static String status(int balance) => balance > 0
      ? receive
      : balance < 0
      ? send
      : balanced;
  static String person(String name, String id, String myId) =>
      id == myId ? '$name (본인)' : name;
  static String memberTitle(String name) => '$name · 정산 상세';
  static String transferCount(int count) => '$count건';
  static String checkedAt(DateTime time) =>
      '확인한 시각 ${time.toLocal().hour.toString().padLeft(2, '0')}:${time.toLocal().minute.toString().padLeft(2, '0')}';
}
