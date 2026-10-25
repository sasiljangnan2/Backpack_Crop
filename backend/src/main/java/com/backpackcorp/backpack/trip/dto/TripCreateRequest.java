package com.backpackcorp.backpack.trip.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

// timeZone은 선택. 없으면 Asia/Seoul (앱은 여행지에 맞게 보내는 것을 권장)
public record TripCreateRequest(
	@NotBlank(message = "여행 이름을 입력해 주세요.")
	@Size(max = 50, message = "여행 이름은 50자 이하로 입력해 주세요.")
	String name,

	@NotBlank(message = "여행지를 입력해 주세요.")
	@Size(max = 100, message = "여행지는 100자 이하로 입력해 주세요.")
	String destination,

	@NotNull(message = "출발일을 입력해 주세요.")
	LocalDate startDate,

	@NotNull(message = "도착일을 입력해 주세요.")
	LocalDate endDate,

	@NotBlank(message = "통화를 선택해 주세요.")
	@Pattern(regexp = "[A-Za-z]{3}", message = "통화 코드는 영문 3자리예요.")
	String currencyCode,

	@Size(max = 40, message = "시간대 이름이 너무 길어요.")
	String timeZone
) {
}
