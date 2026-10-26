package com.backpackcorp.backpack.trip.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.user.domain.User;

// 멤버 목록의 한 명
public record TripMemberResponse(
	UUID memberId,
	String name,
	TripMemberRole role,
	// is로 시작하는 boolean은 JSON 키에서 is가 빠질 수 있어 이름을 고정한다
	@JsonProperty("isMe") boolean isMe,
	BigDecimal prepaidRate,
	Instant joinedAt
) {

	public static TripMemberResponse of(TripMember member, UUID myMemberId) {
		return new TripMemberResponse(member.getId(), displayName(member), member.getRole(),
			member.getId().equals(myMemberId), member.getPrepaidRate(), member.getJoinedAt());
	}

	// 게스트(user 없음)와 탈퇴 회원은 display_name에 남겨 둔 이름을 쓴다
	private static String displayName(TripMember member) {
		User user = member.getUser();
		return user == null || user.getDeletedAt() != null ? member.getDisplayName() : user.getName();
	}
}
