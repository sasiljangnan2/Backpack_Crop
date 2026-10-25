package com.backpackcorp.backpack.schedule.dto;

import java.time.LocalDate;
import java.time.LocalTime;

import com.backpackcorp.backpack.schedule.domain.ReservationStatus;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

// 시각은 여행지 현지 기준 "HH:mm". 초는 버린다
public record ScheduleCreateRequest(
	@NotNull(message = "날짜를 선택해 주세요.")
	LocalDate day,

	@NotNull(message = "시작 시간을 입력해 주세요.")
	LocalTime startTime,

	@NotNull(message = "종료 시간을 입력해 주세요.")
	LocalTime endTime,

	@NotBlank(message = "일정 이름을 입력해 주세요.")
	@Size(max = 100, message = "일정 이름은 100자 이하로 입력해 주세요.")
	String title,

	@Size(max = 100, message = "장소는 100자 이하로 입력해 주세요.")
	String placeText,

	ReservationStatus reservationStatus,

	@Size(max = 500, message = "메모는 500자 이하로 입력해 주세요.")
	String memo,

	Boolean isLocked
) {
}
