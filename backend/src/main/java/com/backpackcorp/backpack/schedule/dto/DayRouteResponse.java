package com.backpackcorp.backpack.schedule.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.place.dto.TravelLeg;

// BP-SC-001 ① · BP-SC-004 그날 동선. 좌표가 있는 일정끼리 시간 순서대로 잇는다.
// missingPlaceCount: 장소 좌표가 없어 지도에 못 그린 일정 수
public record DayRouteResponse(
	LocalDate day,
	List<Leg> legs,
	int totalDistanceM,
	int totalMin,
	int placedCount,
	int missingPlaceCount
) {

	public record Leg(
		UUID fromScheduleId,
		UUID toScheduleId,
		TravelLeg travel
	) {
	}
}
