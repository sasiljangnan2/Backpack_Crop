package com.backpackcorp.backpack.trip.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

// 보낸 값만 바뀐다. 기간은 startDate·endDate 중 하나만 보내도 된다
public record TripUpdateRequest(
	@Size(min = 1, max = 50, message = "여행 이름은 1~50자로 입력해 주세요.")
	String name,

	@Size(min = 1, max = 100, message = "여행지는 1~100자로 입력해 주세요.")
	String destination,

	LocalDate startDate,

	LocalDate endDate,

	@Pattern(regexp = "[A-Za-z]{3}", message = "통화 코드는 영문 3자리예요.")
	String currencyCode,

	@Size(max = 40, message = "시간대 이름이 너무 길어요.")
	String timeZone
) {
}
