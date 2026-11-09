package com.backpackcorp.backpack.trip.dto;

import java.util.UUID;

// 여행별 현재 멤버 수 (JPQL 생성자 표현식용)
public record TripMemberCountDto(
	UUID tripId,
	Long count
) {
}
