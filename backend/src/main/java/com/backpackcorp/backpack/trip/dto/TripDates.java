package com.backpackcorp.backpack.trip.dto;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripStatus;

// 여행 상태 · D-day · 며칠째 계산 (응답 조립용)
public record TripDates(
	TripStatus status,
	long dDay,
	Integer dayNo,
	long nights
) {

	public static TripDates of(Trip trip, LocalDate today) {
		TripStatus status = trip.statusOn(today);
		long dDay = ChronoUnit.DAYS.between(today, trip.getStartDate());
		Integer dayNo = status == TripStatus.LIVE
			? (int)ChronoUnit.DAYS.between(trip.getStartDate(), today) + 1
			: null;
		long nights = ChronoUnit.DAYS.between(trip.getStartDate(), trip.getEndDate());
		return new TripDates(status, dDay, dayNo, nights);
	}
}
