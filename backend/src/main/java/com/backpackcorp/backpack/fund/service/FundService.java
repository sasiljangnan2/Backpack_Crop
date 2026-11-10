package com.backpackcorp.backpack.fund.service;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.expense.dto.MemberAmountDto;
import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.expense.repository.ExpenseRepository;
import com.backpackcorp.backpack.fund.domain.FundContribution;
import com.backpackcorp.backpack.fund.dto.FundContributionRequest;
import com.backpackcorp.backpack.fund.dto.FundResponse;
import com.backpackcorp.backpack.fund.repository.FundContributionRepository;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.dto.TripNotificationEvent;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.RequiredArgsConstructor;

// 공금: 멤버가 돈을 모아 두고 지출을 거기서 낸다.
// 잔액 = 모은 돈 - 공금에서 낸 지출. 정산에서는 모은 돈을 낸 돈으로 치고, 남은 공금은 돌려받는 송금으로 나온다 (SettlementService)
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class FundService {

	private final TripMemberGuard tripMemberGuard;
	private final TripMemberRepository tripMemberRepository;
	private final FundContributionRepository fundContributionRepository;
	private final ExpenseRepository expenseRepository;
	private final ApplicationEventPublisher eventPublisher;
	private final Clock clock;

	public FundResponse getFund(UUID tripId, UUID userId) {
		return fundOf(tripMemberGuard.requireMember(tripId, userId));
	}

	public FundResponse fundOf(TripMember me) {
		UUID tripId = me.getTrip().getId();
		List<FundContribution> contributions = fundContributionRepository.findAllWithMembers(tripId);
		Map<UUID, Long> byMember = contributions.stream().collect(Collectors.groupingBy(
			c -> c.getMember().getId(), Collectors.summingLong(c -> c.getAmountKrw().longValueExact())));
		long collected = byMember.values().stream().mapToLong(Long::longValue).sum();
		long spent = expenseRepository.sumFundSpent(tripId, null).longValueExact();
		List<FundResponse.MemberTotal> members = tripMemberRepository.findAllWithUserByTripId(tripId).stream()
			.filter(member -> member.getLeftAt() == null || byMember.containsKey(member.getId()))
			.map(member -> new FundResponse.MemberTotal(MemberRef.from(member),
				byMember.getOrDefault(member.getId(), 0L)))
			.toList();
		return new FundResponse(collected, spent, collected - spent, members, contributions.stream()
			.map(c -> new FundResponse.Contribution(c.getId(), MemberRef.from(c.getMember()),
				c.getAmountKrw().longValueExact(), c.getContributedOn(), c.getMemo(), MemberRef.from(c.getCreator()),
				canEdit(c, me)))
			.toList());
	}

	@Transactional
	public FundResponse addContribution(UUID tripId, UUID userId, FundContributionRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		TripMember member = requireCurrentMember(tripId, request.memberId());
		fundContributionRepository.save(FundContribution.builder()
			.trip(trip)
			.member(member)
			.creator(me)
			.amountKrw(BigDecimal.valueOf(request.amountKrw()))
			.contributedOn(dateOf(trip, request))
			.memo(blankToNull(request.memo()))
			.build());
		fundContributionRepository.flush();
		String message = MemberRef.nameOf(member) + "님이 공금 ₩" + String.format("%,d", request.amountKrw()) + "을 모았어요";
		eventPublisher.publishEvent(TripNotificationEvent.of(trip, me, NotificationType.EXPENSE_ADDED, message,
			NotificationRefType.TRIP, tripId));
		return fundOf(me);
	}

	@Transactional
	public FundResponse updateContribution(UUID tripId, UUID contributionId, UUID userId,
		FundContributionRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		FundContribution contribution = findEditable(tripId, contributionId, me);
		requireRemaining(tripId, contribution.getAmountKrw().longValueExact() - request.amountKrw());
		contribution.update(requireCurrentMember(tripId, request.memberId()),
			BigDecimal.valueOf(request.amountKrw()), dateOf(me.getTrip(), request), blankToNull(request.memo()));
		fundContributionRepository.flush();
		return fundOf(me);
	}

	@Transactional
	public FundResponse deleteContribution(UUID tripId, UUID contributionId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		FundContribution contribution = findEditable(tripId, contributionId, me);
		requireRemaining(tripId, contribution.getAmountKrw().longValueExact());
		fundContributionRepository.delete(contribution);
		fundContributionRepository.flush();
		return fundOf(me);
	}

	// 공금 지출을 저장하기 전에 잔액을 확인한다. excludeExpenseId: 수정 중인 지출 자신.
	// ponytail: 동시에 저장하면 잔액이 잠깐 음수가 될 수 있다. 그래도 정산에서 "공금 채우기"로 맞춰지므로 잠그지 않는다
	public void requireBalance(UUID tripId, long amountKrw, UUID excludeExpenseId) {
		long remaining = collected(tripId) - expenseRepository.sumFundSpent(tripId, excludeExpenseId).longValueExact();
		if (amountKrw > remaining) {
			throw BaseException.of(ErrorCode.FUND_INSUFFICIENT, "remainingKrw",
				"공금이 " + won(amountKrw - remaining) + " 모자라요 (잔액 " + won(remaining) + "). 공금을 더 모으거나 결제자를 바꿔 주세요.");
		}
	}

	// 모은 돈을 줄이거나 지운 뒤에도 이미 쓴 공금은 남아 있어야 한다
	private void requireRemaining(UUID tripId, long decreaseKrw) {
		long remaining = collected(tripId) - expenseRepository.sumFundSpent(tripId, null).longValueExact();
		if (decreaseKrw > remaining) {
			throw BaseException.of(ErrorCode.FUND_INSUFFICIENT, "remainingKrw",
				"이미 쓴 공금이 있어 줄일 수 없어요 (잔액 " + won(remaining) + ").");
		}
	}

	private long collected(UUID tripId) {
		return fundContributionRepository.sumByMember(tripId).stream().mapToLong(MemberAmountDto::amount).sum();
	}

	private FundContribution findEditable(UUID tripId, UUID contributionId, TripMember me) {
		FundContribution contribution = fundContributionRepository.findInTrip(contributionId, tripId)
			.orElseThrow(() -> new BaseException(ErrorCode.FUND_CONTRIBUTION_NOT_FOUND));
		if (!canEdit(contribution, me)) {
			throw new BaseException(ErrorCode.NOT_FUND_EDITOR);
		}
		return contribution;
	}

	private TripMember requireCurrentMember(UUID tripId, UUID memberId) {
		return tripMemberRepository.findAllWithUserByTripId(tripId).stream()
			.filter(member -> member.getLeftAt() == null && member.getId().equals(memberId))
			.findFirst()
			.orElseThrow(() -> BaseException.of(ErrorCode.VALIDATION_ERROR, "memberId", "이 여행의 멤버만 선택할 수 있어요."));
	}

	private LocalDate dateOf(Trip trip, FundContributionRequest request) {
		return request.contributedOn() != null
			? request.contributedOn()
			: LocalDate.now(clock.withZone(ZoneId.of(trip.getTimeZone())));
	}

	private static boolean canEdit(FundContribution contribution, TripMember me) {
		return me.isHost() || contribution.getMember().getId().equals(me.getId())
			|| contribution.getCreator().getId().equals(me.getId());
	}

	private static String won(long amount) {
		return "₩" + String.format("%,d", amount);
	}

	private static String blankToNull(String value) {
		return value == null || value.isBlank() ? null : value.trim();
	}
}
