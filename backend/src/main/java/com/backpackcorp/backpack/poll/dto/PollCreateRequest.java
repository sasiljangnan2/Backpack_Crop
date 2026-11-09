package com.backpackcorp.backpack.poll.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

// slotDate / slotStart / slotEnd: 투표로 정한 장소를 넣을 일정 시간 (여행지 현지 기준)
public record PollCreateRequest(
	@NotBlank(message = "투표 제목을 입력해 주세요.")
	@Size(max = 100, message = "투표 제목은 100자 이하로 입력해 주세요.")
	String title,

	@NotNull(message = "날짜를 선택해 주세요.")
	LocalDate slotDate,

	@NotNull(message = "시작 시간을 입력해 주세요.")
	LocalTime slotStart,

	@NotNull(message = "종료 시간을 입력해 주세요.")
	LocalTime slotEnd,

	Instant deadlineAt,

	@NotNull(message = "후보를 입력해 주세요.")
	@Size(min = 2, max = 6, message = "후보는 2~6개로 입력해 주세요.")
	List<@Valid OptionRequest> options
) {

	public record OptionRequest(
		@NotBlank(message = "후보 이름을 입력해 주세요.")
		@Size(max = 100, message = "후보 이름은 100자 이하로 입력해 주세요.")
		String label,

		@Size(max = 255, message = "메모는 255자 이하로 입력해 주세요.")
		String memo
	) {
	}
}
