package com.backpackcorp.backpack.expense.dto;

import java.util.UUID;

import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.user.domain.User;

// 응답에 들어가는 멤버 한 명. 지출·정산은 사용자 ID가 아니라 멤버 ID로 사람을 가리킨다
public record MemberRef(
	UUID memberId,
	String name
) {

	public static MemberRef from(TripMember member) {
		return new MemberRef(member.getId(), nameOf(member));
	}

	// 게스트와 탈퇴 회원은 display_name에 남은 이름을 쓴다
	public static String nameOf(TripMember member) {
		User user = member.getUser();
		if (user == null || user.getDeletedAt() != null) {
			return member.getDisplayName() != null ? member.getDisplayName() : "알 수 없음";
		}
		return user.getName();
	}
}
