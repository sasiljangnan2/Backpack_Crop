package com.backpackcorp.backpack.schedule.dto;

import java.time.LocalDate;
import java.time.LocalTime;

import com.backpackcorp.backpack.schedule.domain.ReservationStatus;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

// version은 필수, 나머지는 보낸 값만 바뀐다. placeText·memo는 빈 문자열("")을 보내면 지워진다.
// 고정된 일정은 isLocked=false 하나만 보내 고정을 푼 뒤에 고칠 수 있다
public record ScheduleUpdateRequest(
	@NotNull(message = "version이 필요해요. 일정을 다시 불러와 주세요.")
	Integer version,

	LocalDate day,

	LocalTime startTime,

	LocalTime endTime,

	@Size(min = 1, max = 100, message = "일정 이름은 1~100자로 입력해 주세요.")
	String title,

	@Size(max = 100, message = "장소는 100자 이하로 입력해 주세요.")
	String placeText,

	ReservationStatus reservationStatus,

	@Size(max = 500, message = "메모는 500자 이하로 입력해 주세요.")
	String memo,

	Boolean isLocked
) {

	public boolean changesOtherThanLock() {
		return day != null || startTime != null || endTime != null || title != null || placeText != null
			|| reservationStatus != null || memo != null;
	}
}
