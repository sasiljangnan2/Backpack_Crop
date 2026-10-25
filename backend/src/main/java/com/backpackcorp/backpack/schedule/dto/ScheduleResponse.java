package com.backpackcorp.backpack.schedule.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.schedule.domain.ReservationStatus;
import com.backpackcorp.backpack.schedule.domain.Schedule;
import com.backpackcorp.backpack.schedule.domain.ScheduleActivity;
import com.fasterxml.jackson.annotation.JsonFormat;

// 시각은 여행지 현지 기준 "HH:mm". activity는 활동 기록이 없으면 null
public record ScheduleResponse(
	UUID id,
	LocalDate day,
	@JsonFormat(pattern = "HH:mm") LocalTime startTime,
	@JsonFormat(pattern = "HH:mm") LocalTime endTime,
	String title,
	String placeText,
	boolean isLocked,
	ReservationStatus reservationStatus,
	String memo,
	ScheduleStatus status,
	ActivityResponse activity,
	MemberRef createdBy,
	int version,
	Instant updatedAt
) {

	public record ActivityResponse(
		@JsonFormat(pattern = "HH:mm") LocalTime actualStartTime,
		@JsonFormat(pattern = "HH:mm") LocalTime actualEndTime,
		int delayMin,
		MemberRef recordedBy
	) {

		public static ActivityResponse from(ScheduleActivity activity) {
			return activity == null ? null : new ActivityResponse(activity.getActualStartTime(),
				activity.getActualEndTime(), activity.getDelayMin(), MemberRef.from(activity.getRecordedBy()));
		}
	}

	public static ScheduleResponse of(Schedule schedule, ScheduleActivity activity, LocalDate today, LocalTime now) {
		return new ScheduleResponse(schedule.getId(), schedule.getDay(), schedule.getStartTime(), schedule.getEndTime(),
			schedule.getTitle(), schedule.getPlaceText(), schedule.isLocked(), schedule.getReservationStatus(),
			schedule.getMemo(), ScheduleStatus.of(schedule, activity != null, today, now),
			ActivityResponse.from(activity), MemberRef.from(schedule.getCreatedBy()), schedule.getVersion(),
			schedule.getUpdatedAt());
	}
}
