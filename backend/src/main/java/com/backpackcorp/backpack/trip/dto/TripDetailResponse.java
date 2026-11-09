package com.backpackcorp.backpack.trip.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.trip.domain.TripStatus;

// 여행 상세 (BP-HM-001 여행 메인, BP-HM-002 초대 코드 공유). 초대 코드는 멤버에게만 보인다
public record TripDetailResponse(
	UUID id,
	String name,
	String destination,
	LocalDate startDate,
	LocalDate endDate,
	long nights,
	String currencyCode,
	String timeZone,
	String inviteCode,
	TripStatus status,
	long dDay,
	Integer dayNo,
	UUID myMemberId,
	TripMemberRole myRole,
	int memberCount,
	List<TripMemberResponse> members,
	Instant createdAt
) {

	public static TripDetailResponse of(Trip trip, TripMember me, List<TripMember> activeMembers, LocalDate today) {
		TripDates dates = TripDates.of(trip, today);
		List<TripMemberResponse> members = activeMembers.stream()
			.map(member -> TripMemberResponse.of(member, me.getId()))
			.toList();
		return new TripDetailResponse(trip.getId(), trip.getName(), trip.getDestination(), trip.getStartDate(),
			trip.getEndDate(), dates.nights(), trip.getCurrencyCode(), trip.getTimeZone(), trip.getInviteCode(),
			dates.status(), dates.dDay(), dates.dayNo(), me.getId(), me.getRole(), members.size(), members,
			trip.getCreatedAt());
	}
}
