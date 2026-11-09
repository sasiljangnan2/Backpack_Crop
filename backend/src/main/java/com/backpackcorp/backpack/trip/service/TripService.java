package com.backpackcorp.backpack.trip.service;

import java.time.Clock;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.Currency;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.expense.repository.ExpenseRepository;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.dto.TripNotificationEvent;
import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.schedule.repository.ScheduleRepository;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.trip.domain.TripStatus;
import com.backpackcorp.backpack.trip.dto.PrepaidRateRequest;
import com.backpackcorp.backpack.trip.dto.TripCreateRequest;
import com.backpackcorp.backpack.trip.dto.TripDetailResponse;
import com.backpackcorp.backpack.trip.dto.TripMemberCountDto;
import com.backpackcorp.backpack.trip.dto.TripMemberResponse;
import com.backpackcorp.backpack.trip.dto.TripSummaryResponse;
import com.backpackcorp.backpack.trip.dto.TripUpdateRequest;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.repository.TripRepository;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

// 여행 만들기 · 목록 · 상세 · 수정 · 삭제, 초대 코드 참여, 멤버 관리
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TripService {

	// 한 여행에 참여할 수 있는 최대 인원
	static final int MAX_MEMBERS = 30;
	// 너무 긴 기간은 입력 실수로 본다
	static final int MAX_TRIP_DAYS = 365;
	private static final int INVITE_CODE_ATTEMPTS = 10;

	private final TripRepository tripRepository;
	private final TripMemberRepository tripMemberRepository;
	private final UserRepository userRepository;
	private final ScheduleRepository scheduleRepository;
	private final ExpenseRepository expenseRepository;
	private final TripMemberGuard tripMemberGuard;
	private final InviteCodeGenerator inviteCodeGenerator;
	private final ApplicationEventPublisher eventPublisher;
	private final Clock clock;

	@Transactional
	public TripDetailResponse createTrip(UUID userId, TripCreateRequest request) {
		User user = activeUser(userId);
		validatePeriod(request.startDate(), request.endDate());
		Trip trip = tripRepository.save(Trip.builder()
			.name(request.name().trim())
			.destination(request.destination().trim())
			.startDate(request.startDate())
			.endDate(request.endDate())
			.currencyCode(currency(request.currencyCode()))
			.timeZone(request.timeZone() == null || request.timeZone().isBlank()
				? Trip.DEFAULT_TIME_ZONE
				: zone(request.timeZone()))
			.inviteCode(newInviteCode())
			.build());
		TripMember host = tripMemberRepository.save(
			TripMember.builder().trip(trip).user(user).role(TripMemberRole.HOST).build());
		return TripDetailResponse.of(trip, host, List.of(host), today(trip));
	}

	// 여행 중 → 다가오는 여행(가까운 순) → 지난 여행(최근 순)
	public List<TripSummaryResponse> getMyTrips(UUID userId) {
		List<TripMember> memberships = tripMemberRepository.findActiveWithTripByUserId(userId);
		if (memberships.isEmpty()) {
			return List.of();
		}
		Map<UUID, Long> counts = tripMemberRepository
			.countActiveByTripIds(memberships.stream().map(m -> m.getTrip().getId()).toList()).stream()
			.collect(Collectors.toMap(TripMemberCountDto::tripId, TripMemberCountDto::count));
		return memberships.stream()
			.map(m -> TripSummaryResponse.of(m.getTrip(), today(m.getTrip()), counts.getOrDefault(m.getTrip().getId(),
				0L), m.getRole()))
			.sorted(LIST_ORDER)
			.toList();
	}

	private static final Comparator<TripSummaryResponse> LIST_ORDER = Comparator
		.comparingInt((TripSummaryResponse t) -> switch (t.status()) {
			case LIVE -> 0;
			case UPCOMING -> 1;
			case DONE -> 2;
		})
		.thenComparing((a, b) -> a.status() == TripStatus.DONE
			? b.startDate().compareTo(a.startDate())
			: a.startDate().compareTo(b.startDate()))
		.thenComparing(TripSummaryResponse::id);

	public TripDetailResponse getTrip(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		return detail(me);
	}

	@Transactional
	public TripDetailResponse updateTrip(UUID tripId, UUID userId, TripUpdateRequest request) {
		TripMember me = tripMemberGuard.requireHost(tripId, userId);
		Trip trip = me.getTrip();

		if (request.name() != null || request.destination() != null) {
			trip.changeInfo(request.name() != null ? notBlank("name", request.name()) : trip.getName(),
				request.destination() != null ? notBlank("destination", request.destination()) : trip.getDestination());
		}
		if (request.startDate() != null || request.endDate() != null) {
			LocalDate start = request.startDate() != null ? request.startDate() : trip.getStartDate();
			LocalDate end = request.endDate() != null ? request.endDate() : trip.getEndDate();
			validatePeriod(start, end);
			long outside = scheduleRepository.countOutside(tripId, start, end);
			if (outside > 0) {
				throw BaseException.of(ErrorCode.TRIP_PERIOD_CONFLICT, "scheduleCount", String.valueOf(outside));
			}
			trip.changePeriod(start, end);
		}
		if (request.currencyCode() != null) {
			String currency = currency(request.currencyCode());
			if (!currency.equals(trip.getCurrencyCode())) {
				if (expenseRepository.existsByTripId(tripId)) {
					throw new BaseException(ErrorCode.TRIP_CURRENCY_LOCKED);
				}
				trip.changeCurrency(currency);
			}
		}
		if (request.timeZone() != null) {
			trip.changeTimeZone(zone(request.timeZone()));
		}
		return detail(me);
	}

	// 하위 데이터(멤버·일정·지출·정산 등)는 DB의 ON DELETE CASCADE로 함께 지워진다
	@Transactional
	public void deleteTrip(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireHost(tripId, userId);
		// 멤버가 지워지기 전에 알림을 만든다 (알림은 여행과 FK가 없어 삭제 뒤에도 남는다)
		eventPublisher.publishEvent(TripNotificationEvent.of(me.getTrip(), me, NotificationType.TRIP_DELETED,
			MemberRef.nameOf(me) + "님이 '" + me.getTrip().getName() + "' 여행을 삭제했어요", null, null));
		tripRepository.delete(me.getTrip());
	}

	// 이미 멤버면 그 여행을 그대로 돌려준다. 나갔던 여행이면 같은 멤버 행을 되살린다
	// (나가기 전 지출·정산 기록이 그 행을 가리키고 있다)
	@Transactional
	public TripDetailResponse joinTrip(UUID userId, String inviteCode) {
		User user = activeUser(userId);
		String code = InviteCodeGenerator.normalize(inviteCode);
		Trip trip = tripRepository.findByInviteCode(code)
			.orElseThrow(() -> BaseException.of(ErrorCode.INVITE_CODE_NOT_FOUND, "inviteCode", code));
		Optional<TripMember> existing = tripMemberRepository.findByTripIdAndUserId(trip.getId(), userId);
		if (existing.isPresent() && existing.get().isActive()) {
			return detail(existing.get());
		}
		if (tripMemberRepository.countByTripIdAndLeftAtIsNull(trip.getId()) >= MAX_MEMBERS) {
			throw new BaseException(ErrorCode.TRIP_FULL);
		}
		TripMember member = existing.map(left -> {
			left.rejoin();
			return left;
		}).orElseGet(() -> tripMemberRepository.save(
			TripMember.builder().trip(trip).user(user).role(TripMemberRole.MEMBER).build()));
		eventPublisher.publishEvent(TripNotificationEvent.of(trip, member, NotificationType.MEMBER_JOINED,
			MemberRef.nameOf(member) + "님이 여행에 참여했어요", NotificationRefType.TRIP, trip.getId()));
		return detail(member);
	}

	public List<TripMemberResponse> getMembers(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		return activeMembers(tripId).stream().map(member -> TripMemberResponse.of(member, me.getId())).toList();
	}

	@Transactional
	public void leaveTrip(UUID tripId, UUID userId) {
		leave(tripMemberGuard.requireMember(tripId, userId));
	}

	@Transactional
	public TripMemberResponse changePrepaidRate(UUID tripId, UUID userId, PrepaidRateRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		me.changePrepaidRate(request.prepaidRate() == null ? null : request.prepaidRate().setScale(6));
		return TripMemberResponse.of(me, me.getId());
	}

	// 탈퇴할 때: 참여 중인 모든 여행에서 나가고, 멤버 행에 그 시점 이름을 남긴다
	@Transactional
	public void leaveAllTrips(UUID userId, String name) {
		for (TripMember member : tripMemberRepository.findActiveWithTripByUserId(userId)) {
			member.keepDisplayName(name);
			leave(member);
		}
	}

	// 방장이 나가면 가장 먼저 참여한 멤버가 방장이 된다. 남은 멤버가 없으면 여행은 그대로 둔다
	// (초대 코드로 다시 들어오면 기록을 이어서 볼 수 있다)
	private void leave(TripMember member) {
		member.leave(Instant.now(clock));
		if (!member.isHost()) {
			return;
		}
		member.changeRole(TripMemberRole.MEMBER);
		activeMembers(member.getTrip().getId()).stream()
			.filter(other -> !other.getId().equals(member.getId()))
			.findFirst()
			.ifPresent(next -> next.changeRole(TripMemberRole.HOST));
	}

	private TripDetailResponse detail(TripMember me) {
		Trip trip = me.getTrip();
		return TripDetailResponse.of(trip, me, activeMembers(trip.getId()), today(trip));
	}

	private List<TripMember> activeMembers(UUID tripId) {
		return tripMemberRepository.findAllWithUserByTripId(tripId).stream().filter(TripMember::isActive).toList();
	}

	private LocalDate today(Trip trip) {
		return LocalDate.now(clock.withZone(trip.zoneId()));
	}

	private User activeUser(UUID userId) {
		return userRepository.findById(userId)
			.filter(user -> !user.isDeleted())
			.orElseThrow(() -> new BaseException(ErrorCode.UNAUTHORIZED));
	}

	private String newInviteCode() {
		for (int i = 0; i < INVITE_CODE_ATTEMPTS; i++) {
			String code = inviteCodeGenerator.generate();
			if (!tripRepository.existsByInviteCode(code)) {
				return code;
			}
		}
		// 1조 가지 중 10번 연속 충돌은 사실상 일어나지 않는다. 일어나면 생성기 문제다
		throw new IllegalStateException("초대 코드를 만들지 못했습니다");
	}

	private static void validatePeriod(LocalDate start, LocalDate end) {
		if (end.isBefore(start)) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "endDate", "도착일은 출발일과 같거나 늦어야 해요.");
		}
		if (ChronoUnit.DAYS.between(start, end) >= MAX_TRIP_DAYS) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "endDate", "여행 기간은 1년을 넘을 수 없어요.");
		}
	}

	private static String currency(String code) {
		String upper = code.trim().toUpperCase(Locale.ROOT);
		try {
			return Currency.getInstance(upper).getCurrencyCode();
		} catch (IllegalArgumentException e) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "currencyCode", "지원하지 않는 통화예요.");
		}
	}

	private static String zone(String timeZone) {
		try {
			return ZoneId.of(timeZone.trim()).getId();
		} catch (DateTimeException e) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "timeZone", "시간대 이름이 올바르지 않아요. (예: Asia/Tokyo)");
		}
	}

	private static String notBlank(String field, String value) {
		if (value.isBlank()) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, field, "비워 둘 수 없어요.");
		}
		return value.trim();
	}
}
