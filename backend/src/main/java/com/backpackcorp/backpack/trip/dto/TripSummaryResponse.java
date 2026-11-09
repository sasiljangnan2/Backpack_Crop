package com.backpackcorp.backpack.trip.dto;

import java.time.LocalDate;
import java.util.UUID;

import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.trip.domain.TripStatus;

// 내 여행 목록의 한 줄 (BP-TR-001).
// dDay: 출발일까지 남은 날 (여행지 기준 오늘). 0이면 출발일, 음수면 이미 출발했다
// dayNo: 여행 중이면 며칠째인지 (1부터). 여행 중이 아니면 null
public record TripSummaryResponse(
	UUID id,
	String name,
	String destination,
	LocalDate startDate,
	LocalDate endDate,
	String currencyCode,
	TripStatus status,
	long dDay,
	Integer dayNo,
	long memberCount,
	TripMemberRole myRole
) {

	public static TripSummaryResponse of(Trip trip, LocalDate today, long memberCount, TripMemberRole myRole) {
		TripDates dates = TripDates.of(trip, today);
		return new TripSummaryResponse(trip.getId(), trip.getName(), trip.getDestination(), trip.getStartDate(),
			trip.getEndDate(), trip.getCurrencyCode(), dates.status(), dates.dDay(), dates.dayNo(), memberCount,
			myRole);
	}
}
