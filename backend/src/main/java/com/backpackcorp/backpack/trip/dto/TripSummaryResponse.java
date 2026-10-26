package com.backpackcorp.backpack.trip.dto;

import java.time.LocalDate;
import java.util.UUID;

import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;

// 내 여행 목록의 카드 한 장. 초대 코드는 상세에서만 준다
public record TripSummaryResponse(
	UUID id,
	String name,
	String destination,
	LocalDate startDate,
	LocalDate endDate,
	String currencyCode,
	long memberCount,
	TripMemberRole myRole
) {

	public static TripSummaryResponse of(Trip trip, long memberCount, TripMemberRole myRole) {
		return new TripSummaryResponse(trip.getId(), trip.getName(), trip.getDestination(), trip.getStartDate(),
			trip.getEndDate(), trip.getCurrencyCode(), memberCount, myRole);
	}
}
