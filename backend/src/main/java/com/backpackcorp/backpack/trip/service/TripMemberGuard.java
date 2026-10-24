package com.backpackcorp.backpack.trip.service;

import java.util.UUID;

import org.springframework.stereotype.Component;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;

import lombok.RequiredArgsConstructor;

// 여행에 딸린 API(준비 업무·일정·투표·지출·정산)가 공통으로 쓰는 권한 확인.
// 로그인한 사용자가 그 여행의 현재 멤버인지 확인하고 멤버를 돌려준다.
// 일정·지출 등은 작성자를 사용자 ID가 아니라 멤버 ID로 저장하므로, 돌려받은 멤버를 그대로 쓰면 된다.
//   TripMember me = tripMemberGuard.requireMember(tripId, user.getId());
//
// 게스트는 user_id가 없어 여기서 찾을 수 없다. 게스트 인증 방식이 정해지면 게스트용 조회를 추가한다
@Component
@RequiredArgsConstructor
public class TripMemberGuard {

	private final TripMemberRepository tripMemberRepository;

	// 멤버가 아니거나 이미 나간 멤버면 NOT_TRIP_MEMBER. 여행이 없을 때도 같은 응답이다 (여행의 존재를 알려 주지 않는다)
	public TripMember requireMember(UUID tripId, UUID userId) {
		return tripMemberRepository.findByTripIdAndUserIdAndLeftAtIsNull(tripId, userId)
			.orElseThrow(() -> new BaseException(ErrorCode.NOT_TRIP_MEMBER));
	}

	// 여행 삭제처럼 방장만 할 수 있는 일에 쓴다
	public TripMember requireHost(UUID tripId, UUID userId) {
		TripMember member = requireMember(tripId, userId);
		if (member.getRole() != TripMemberRole.HOST) {
			throw new BaseException(ErrorCode.NOT_TRIP_HOST);
		}
		return member;
	}
}
