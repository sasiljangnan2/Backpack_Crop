package com.backpackcorp.backpack.schedule.dto;

import java.time.LocalTime;

import jakarta.validation.constraints.NotNull;

// 실제로 시작·종료한 현지 시각. 지연 = 실제 종료 − 계획 종료 (일찍 끝나면 0)
public record ActivityRequest(
	@NotNull(message = "실제 시작 시간을 입력해 주세요.")
	LocalTime actualStartTime,

	@NotNull(message = "실제 종료 시간을 입력해 주세요.")
	LocalTime actualEndTime
) {
}
