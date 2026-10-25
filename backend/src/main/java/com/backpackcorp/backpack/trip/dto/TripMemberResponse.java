package com.backpackcorp.backpack.trip.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;

public record TripMemberResponse(
	UUID memberId,
	String name,
	TripMemberRole role,
	boolean isMe,
	BigDecimal prepaidRate,
	Instant joinedAt
) {

	public static TripMemberResponse of(TripMember member, UUID myMemberId) {
		return new TripMemberResponse(member.getId(), MemberRef.nameOf(member), member.getRole(),
			member.getId().equals(myMemberId), member.getPrepaidRate(), member.getJoinedAt());
	}
}
