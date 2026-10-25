package com.backpackcorp.backpack.budget.service.rate;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

// 외부 환율 출처. 통화 1단위 → 원화 값을 돌려준다.
// rateDate는 출처가 실제로 고시한 날짜다 (주말·공휴일이면 요청한 날짜보다 이를 수 있다)
public interface ExchangeRateProvider {

	String name();

	Optional<FetchedRate> fetch(String currencyCode, LocalDate date);

	record FetchedRate(LocalDate rateDate, BigDecimal rateToKrw) {
	}
}
