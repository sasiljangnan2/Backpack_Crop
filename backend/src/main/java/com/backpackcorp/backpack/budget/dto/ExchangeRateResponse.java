package com.backpackcorp.backpack.budget.dto;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;

// unit / unitRateToKrw: 화면 표시용. 엔화처럼 100단위로 읽는 통화는 "100엔 = 935.00원"으로 보여 준다.
// isFallback: 요청한 날짜의 값이 없어 이전 날짜 값을 준 경우 true (앱은 "10.03 기준"처럼 rateDate를 같이 보여 준다)
public record ExchangeRateResponse(
	String currencyCode,
	LocalDate requestedDate,
	LocalDate rateDate,
	BigDecimal rateToKrw,
	int unit,
	BigDecimal unitRateToKrw,
	Instant fetchedAt,
	boolean isFallback
) {

	public static ExchangeRateResponse of(AppliedRate rate, LocalDate requestedDate, int unit) {
		BigDecimal unitRate = rate.rateToKrw().multiply(BigDecimal.valueOf(unit)).setScale(2, RoundingMode.HALF_UP);
		return new ExchangeRateResponse(rate.currencyCode(), requestedDate, rate.rateDate(), rate.rateToKrw(), unit,
			unitRate, rate.fetchedAt(), !requestedDate.equals(rate.rateDate()));
	}
}
