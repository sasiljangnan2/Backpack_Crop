package com.backpackcorp.backpack.schedule.dto;

import java.time.LocalDate;
import java.time.LocalTime;

import com.backpackcorp.backpack.schedule.domain.Schedule;

// 저장하지 않고 계산하는 일정 상태. 활동 기록이 있으면 DONE, 지금 시간대 안이면 IN_PROGRESS
public enum ScheduleStatus {
	PLANNED,
	IN_PROGRESS,
	DONE;

	public static ScheduleStatus of(Schedule schedule, boolean hasActivity, LocalDate today, LocalTime now) {
		if (hasActivity) {
			return DONE;
		}
		boolean running = schedule.getDay().equals(today)
			&& !now.isBefore(schedule.getStartTime()) && now.isBefore(schedule.getEndTime());
		return running ? IN_PROGRESS : PLANNED;
	}
}
