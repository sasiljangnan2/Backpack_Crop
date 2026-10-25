package com.backpackcorp.backpack.trip.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Positive;

// 환전해 간 환율 (여행 통화 1단위 → 원). null이면 해제
public record PrepaidRateRequest(
	@Positive(message = "환율은 0보다 커야 해요.")
	@Digits(integer = 9, fraction = 6, message = "환율은 소수 여섯째 자리까지 입력할 수 있어요.")
	BigDecimal prepaidRate
) {
}
