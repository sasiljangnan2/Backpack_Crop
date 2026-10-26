package com.backpackcorp.backpack.trip.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;

// 여행 상세. 여행 만들기 · 초대 코드 참여도 이 형식으로 응답한다.
// 며칠째 · D-day는 넣지 않는다. 앱이 startDate / endDate로 계산한다
public record TripDetailResponse(
	UUID id,
	String name,
	String destination,
	LocalDate startDate,
	LocalDate endDate,
	String currencyCode,
	String inviteCode,
	// 일정 · 지출 API는 작성자를 사용자 ID가 아니라 멤버 ID로 받는다
	UUID myMemberId,
	TripMemberRole myRole,
	Instant createdAt
) {

	public static TripDetailResponse of(Trip trip, TripMember me) {
		return new TripDetailResponse(trip.getId(), trip.getName(), trip.getDestination(), trip.getStartDate(),
			trip.getEndDate(), trip.getCurrencyCode(), trip.getInviteCode(), me.getId(), me.getRole(),
			trip.getCreatedAt());
	}
}
