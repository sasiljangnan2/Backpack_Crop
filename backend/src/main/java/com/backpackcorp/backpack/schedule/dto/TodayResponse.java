package com.backpackcorp.backpack.schedule.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import com.backpackcorp.backpack.trip.domain.TripStatus;
import com.fasterxml.jackson.annotation.JsonFormat;

// BP-AI-001 오늘 일정 · 진행 요약, BP-HM-001 여행 메인(여행 중).
// date · localTime은 여행지 현지 기준. 지금 진행 중인 일정이 없으면 current가 null
//   current     지금 시간대에 걸친(아직 완료 기록이 없는) 일정
//   next        아직 시작하지 않은 다음 일정
//   nextFixed   다음 고정 일정과 남은 시간(분)
//   delayMin    오늘 활동 기록의 지연 합계 (시안의 "45분 지연" 배너)
public record TodayResponse(
	LocalDate date,
	@JsonFormat(pattern = "HH:mm") LocalTime localTime,
	String timeZone,
	Instant now,
	TripStatus tripStatus,
	Integer dayNo,
	ScheduleResponse current,
	ScheduleResponse next,
	NextFixed nextFixed,
	int delayMin,
	int doneCount,
	int total,
	int remaining,
	List<ScheduleResponse> schedules
) {

	public record NextFixed(
		ScheduleResponse schedule,
		long minutesUntil
	) {
	}
}
