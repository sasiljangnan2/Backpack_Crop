package com.backpackcorp.backpack.trip.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

// 여행 만들기 요청. endDate >= startDate 는 두 필드를 함께 봐야 해서 TripService에서 확인한다
public record TripCreateRequest(
	@NotBlank @Size(max = 50) String name,
	@NotBlank @Size(max = 100) String destination,
	@NotNull LocalDate startDate,
	@NotNull LocalDate endDate,
	// ISO 4217 통화 코드 (예: JPY)
	@NotBlank @Pattern(regexp = "[A-Z]{3}") String currencyCode
) {
}
