package com.backpackcorp.backpack.trip.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.repository.TripRepository;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class TripMemberGuardTest {

	@Autowired
	private TripMemberGuard tripMemberGuard;
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private TripRepository tripRepository;
	@Autowired
	private TripMemberRepository tripMemberRepository;

	private Trip trip;
	private User host;
	private User member;

	@BeforeEach
	void setUp() {
		LocalDate day = LocalDate.of(2026, 1, 1);
		trip = tripRepository.save(Trip.builder().name("오사카").destination("일본 오사카")
			.startDate(day).endDate(day).currencyCode("JPY").inviteCode("ABCD1234").build());
		host = join(user("host@b.c"), TripMemberRole.HOST).getUser();
		member = join(user("member@b.c"), TripMemberRole.MEMBER).getUser();
	}

	@Test
	void 멤버면_그_여행의_멤버를_돌려준다() {
		TripMember found = tripMemberGuard.requireMember(trip.getId(), member.getId());

		assertThat(found.getUser().getId()).isEqualTo(member.getId());
		assertThat(found.getTrip().getId()).isEqualTo(trip.getId());
	}

	@Test
	void 멤버가_아니거나_여행이_없으면_NOT_TRIP_MEMBER다() {
		User stranger = user("stranger@b.c");

		assertRejected(() -> tripMemberGuard.requireMember(trip.getId(), stranger.getId()), ErrorCode.NOT_TRIP_MEMBER);
		assertRejected(() -> tripMemberGuard.requireMember(UUID.randomUUID(), member.getId()),
			ErrorCode.NOT_TRIP_MEMBER);
	}

	@Test
	void 나간_멤버는_멤버가_아니다() {
		TripMember left = tripMemberGuard.requireMember(trip.getId(), member.getId());
		// 나가기 기능이 아직 없어 필드를 직접 채운다
		ReflectionTestUtils.setField(left, "leftAt", Instant.now());
		tripMemberRepository.flush();

		assertRejected(() -> tripMemberGuard.requireMember(trip.getId(), member.getId()), ErrorCode.NOT_TRIP_MEMBER);
	}

	@Test
	void 방장_확인은_방장만_통과한다() {
		assertThat(tripMemberGuard.requireHost(trip.getId(), host.getId()).getRole()).isEqualTo(TripMemberRole.HOST);
		assertRejected(() -> tripMemberGuard.requireHost(trip.getId(), member.getId()), ErrorCode.NOT_TRIP_HOST);
	}

	private User user(String email) {
		return userRepository.save(User.builder().email(email).passwordHash("{bcrypt}hash").name("홍길동").build());
	}

	private TripMember join(User user, TripMemberRole role) {
		return tripMemberRepository.save(TripMember.builder().trip(trip).user(user).role(role).build());
	}

	private static void assertRejected(Runnable call, ErrorCode expected) {
		assertThatThrownBy(call::run).isInstanceOfSatisfying(BaseException.class,
			e -> assertThat(e.getErrorCode()).isEqualTo(expected));
	}
}
