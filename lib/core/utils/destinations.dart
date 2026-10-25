/// 여행 만들기에서 고르는 지역. 통화와 시간대를 함께 정한다.
class DestinationPreset {
  const DestinationPreset(
    this.label,
    this.currencyCode,
    this.timeZone,
    this.currencyName,
  );

  final String label;
  final String currencyCode;
  final String timeZone;
  final String currencyName;
}

const destinationPresets = [
  DestinationPreset('일본', 'JPY', 'Asia/Tokyo', '엔'),
  DestinationPreset('대만', 'TWD', 'Asia/Taipei', '대만 달러'),
  DestinationPreset('중국', 'CNY', 'Asia/Shanghai', '위안'),
  DestinationPreset('홍콩', 'HKD', 'Asia/Hong_Kong', '홍콩 달러'),
  DestinationPreset('태국', 'THB', 'Asia/Bangkok', '바트'),
  DestinationPreset('베트남', 'VND', 'Asia/Ho_Chi_Minh', '동'),
  DestinationPreset('싱가포르', 'SGD', 'Asia/Singapore', '싱가포르 달러'),
  DestinationPreset('필리핀', 'PHP', 'Asia/Manila', '페소'),
  DestinationPreset('괌 · 사이판', 'USD', 'Pacific/Guam', '달러'),
  DestinationPreset('하와이', 'USD', 'Pacific/Honolulu', '달러'),
  DestinationPreset('미국 서부', 'USD', 'America/Los_Angeles', '달러'),
  DestinationPreset('미국 동부', 'USD', 'America/New_York', '달러'),
  DestinationPreset('캐나다', 'CAD', 'America/Toronto', '캐나다 달러'),
  DestinationPreset('유럽 (유로)', 'EUR', 'Europe/Paris', '유로'),
  DestinationPreset('영국', 'GBP', 'Europe/London', '파운드'),
  DestinationPreset('호주', 'AUD', 'Australia/Sydney', '호주 달러'),
  DestinationPreset('국내', 'KRW', 'Asia/Seoul', '원'),
];

DestinationPreset presetFor(String currencyCode, String timeZone) {
  for (final preset in destinationPresets) {
    if (preset.currencyCode == currencyCode && preset.timeZone == timeZone) {
      return preset;
    }
  }
  for (final preset in destinationPresets) {
    if (preset.currencyCode == currencyCode) {
      return preset;
    }
  }
  return destinationPresets.last;
}
