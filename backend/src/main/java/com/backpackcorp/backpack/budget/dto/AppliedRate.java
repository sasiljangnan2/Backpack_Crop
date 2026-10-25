package com.backpackcorp.backpack.budget.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

// 지출 계산에 실제로 쓰는 환율 (계층 간 전달용).
// rateDate는 실제 값이 고시된 날짜라서 요청한 날짜보다 이를 수 있다
public record AppliedRate(
	String currencyCode,
	BigDecimal rateToKrw,
	LocalDate rateDate,
	Instant fetchedAt
) {
}
