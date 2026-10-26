package com.backpackcorp.backpack.trip.service;

import java.security.SecureRandom;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.trip.dto.TripCreateRequest;
import com.backpackcorp.backpack.trip.dto.TripDetailResponse;
import com.backpackcorp.backpack.trip.dto.TripJoinRequest;
import com.backpackcorp.backpack.trip.dto.TripMemberResponse;
import com.backpackcorp.backpack.trip.dto.TripSummaryResponse;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.repository.TripRepository;
import com.backpackcorp.backpack.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

// 여행 만들기 · 내 여행 목록 · 여행 상세 · 초대 코드 참여 · 멤버 목록
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TripService {

	// 헷갈리는 0 O 1 I 를 뺀 대문자 + 숫자
	private static final String INVITE_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
	private static final int INVITE_CODE_LENGTH = 8;
	private static final SecureRandom RANDOM = new SecureRandom();

	private final TripRepository tripRepository;
	private final TripMemberRepository tripMemberRepository;
	private final UserRepository userRepository;
	private final TripMemberGuard tripMemberGuard;

	// 만든 사람이 방장(HOST) 멤버가 된다
	@Transactional
	public TripDetailResponse createTrip(UUID userId, TripCreateRequest request) {
		if (request.endDate().isBefore(request.startDate())) {
			throw new BaseException(ErrorCode.BAD_REQUEST);
		}
		Trip trip = tripRepository.save(Trip.builder()
			.name(request.name())
			.destination(request.destination())
			.startDate(request.startDate())
			.endDate(request.endDate())
			.currencyCode(request.currencyCode())
			.inviteCode(newInviteCode())
			.build());
		// getReferenceById: 회원 행을 읽지 않고 ID만 가진 참조를 만든다 (외래 키만 필요하다)
		TripMember host = tripMemberRepository.save(TripMember.builder()
			.trip(trip)
			.user(userRepository.getReferenceById(userId))
			.role(TripMemberRole.HOST)
			.build());
		return TripDetailResponse.of(trip, host);
	}

	// 내가 현재 멤버인 여행. 시작일 최신순
	public List<TripSummaryResponse> getMyTrips(UUID userId) {
		// ponytail: 여행마다 인원 수 조회가 1번씩 나간다. 여행이 많아지면 group by 한 번으로 바꾼다
		return tripMemberRepository.findByUserIdAndLeftAtIsNullOrderByTripStartDateDesc(userId).stream()
			.map(me -> TripSummaryResponse.of(me.getTrip(),
				tripMemberRepository.countByTripIdAndLeftAtIsNull(me.getTrip().getId()), me.getRole()))
			.toList();
	}

	// 멤버가 아니면 TripMemberGuard가 403 NOT_TRIP_MEMBER (여행이 없어도 같은 응답)
	public TripDetailResponse getTrip(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		return TripDetailResponse.of(me.getTrip(), me);
	}

	// 이미 멤버면 그대로, 나갔던 멤버면 다시 넣고, 처음이면 MEMBER로 추가한다. 세 경우 모두 여행 상세로 응답
	@Transactional
	public TripDetailResponse joinTrip(UUID userId, TripJoinRequest request) {
		String inviteCode = request.inviteCode().trim().toUpperCase(Locale.ROOT);
		Trip trip = tripRepository.findByInviteCode(inviteCode)
			.orElseThrow(() -> new BaseException(ErrorCode.NOT_FOUND));

		TripMember me = tripMemberRepository.findByTripIdAndUserId(trip.getId(), userId)
			.orElseGet(() -> tripMemberRepository.save(TripMember.builder()
				.trip(trip)
				.user(userRepository.getReferenceById(userId))
				.role(TripMemberRole.MEMBER)
				.build()));
		// 이미 현재 멤버면 아무 일도 하지 않는다. 트랜잭션이 끝날 때 바뀐 left_at이 저장된다
		me.rejoin();
		return TripDetailResponse.of(trip, me);
	}

	// 현재 멤버만. 먼저 요청한 사람이 멤버인지 확인한다
	public List<TripMemberResponse> getMembers(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		return tripMemberRepository.findByTripIdAndLeftAtIsNullOrderByJoinedAt(tripId).stream()
			.map(member -> TripMemberResponse.of(member, me.getId()))
			.toList();
	}

	// 겹치면 다시 뽑는다. 32자 중 8자리라 겹칠 일은 거의 없다
	private String newInviteCode() {
		String code;
		do {
			StringBuilder builder = new StringBuilder(INVITE_CODE_LENGTH);
			for (int i = 0; i < INVITE_CODE_LENGTH; i++) {
				builder.append(INVITE_CODE_CHARS.charAt(RANDOM.nextInt(INVITE_CODE_CHARS.length())));
			}
			code = builder.toString();
		} while (tripRepository.existsByInviteCode(code));
		return code;
	}
}
