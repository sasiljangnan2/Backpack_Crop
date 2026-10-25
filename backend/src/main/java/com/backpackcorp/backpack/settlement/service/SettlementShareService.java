package com.backpackcorp.backpack.settlement.service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.dto.TripNotificationEvent;
import com.backpackcorp.backpack.settlement.domain.SettlementShare;
import com.backpackcorp.backpack.settlement.domain.SettlementTransfer;
import com.backpackcorp.backpack.settlement.dto.SettlementResponse;
import com.backpackcorp.backpack.settlement.dto.SettlementShareResponse;
import com.backpackcorp.backpack.settlement.repository.SettlementShareRepository;
import com.backpackcorp.backpack.settlement.repository.SettlementTransferRepository;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.RequiredArgsConstructor;

// 정산 결과 공유: 지금 계산한 송금 목록을 그대로 저장해 둔다 (나중에 "그때 이렇게 보내기로 했다"를 확인)
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SettlementShareService {

	private final TripMemberGuard tripMemberGuard;
	private final TripMemberRepository tripMemberRepository;
	private final SettlementService settlementService;
	private final SettlementShareRepository settlementShareRepository;
	private final SettlementTransferRepository settlementTransferRepository;
	private final ApplicationEventPublisher eventPublisher;

	@Transactional
	public SettlementShareResponse share(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		SettlementResponse current = settlementService.getSettlement(tripId, userId);
		if (current.transfers().isEmpty()) {
			throw new BaseException(ErrorCode.NOTHING_TO_SETTLE);
		}
		Map<UUID, TripMember> members = tripMemberRepository.findAllWithUserByTripId(tripId).stream()
			.collect(Collectors.toMap(TripMember::getId, member -> member));
		SettlementShare share = settlementShareRepository.save(
			SettlementShare.builder().trip(me.getTrip()).sharedBy(me).build());
		List<SettlementTransfer> transfers = current.transfers().stream()
			.map(t -> SettlementTransfer.builder()
				.share(share)
				.fromMember(members.get(t.from().memberId()))
				.toMember(members.get(t.to().memberId()))
				.amountKrw(BigDecimal.valueOf(t.amountKrw()))
				.build())
			.toList();
		settlementTransferRepository.saveAll(transfers);
		eventPublisher.publishEvent(TripNotificationEvent.of(me.getTrip(), me, NotificationType.SETTLEMENT_SHARED,
			MemberRef.nameOf(me) + "님이 정산 결과를 공유했어요 · 송금 " + transfers.size() + "건",
			NotificationRefType.SETTLEMENT_SHARE, share.getId()));
		return toResponse(share, transfers);
	}

	public List<SettlementShareResponse.Summary> getShares(UUID tripId, UUID userId) {
		tripMemberGuard.requireMember(tripId, userId);
		List<SettlementShare> shares = settlementShareRepository.findByTrip(tripId);
		if (shares.isEmpty()) {
			return List.of();
		}
		Map<UUID, List<SettlementTransfer>> transfers = settlementTransferRepository
			.findWithMembersByShareIds(shares.stream().map(SettlementShare::getId).toList()).stream()
			.collect(Collectors.groupingBy(t -> t.getShare().getId()));
		return shares.stream().map(share -> {
			List<SettlementTransfer> list = transfers.getOrDefault(share.getId(), List.of());
			return new SettlementShareResponse.Summary(share.getId(), MemberRef.from(share.getSharedBy()),
				share.getCreatedAt(), list.size(), total(list));
		}).toList();
	}

	public SettlementShareResponse getShare(UUID tripId, UUID shareId, UUID userId) {
		tripMemberGuard.requireMember(tripId, userId);
		SettlementShare share = settlementShareRepository.findInTrip(shareId, tripId)
			.orElseThrow(() -> new BaseException(ErrorCode.SETTLEMENT_SHARE_NOT_FOUND));
		return toResponse(share, settlementTransferRepository.findWithMembersByShareIds(List.of(share.getId())));
	}

	private static SettlementShareResponse toResponse(SettlementShare share, List<SettlementTransfer> transfers) {
		List<SettlementShareResponse.TransferResponse> items = transfers.stream()
			.map(t -> new SettlementShareResponse.TransferResponse(t.getId(), MemberRef.from(t.getFromMember()),
				MemberRef.from(t.getToMember()), t.getAmountKrw().longValueExact()))
			.toList();
		return new SettlementShareResponse(share.getId(), MemberRef.from(share.getSharedBy()), share.getCreatedAt(),
			total(transfers), items);
	}

	private static long total(List<SettlementTransfer> transfers) {
		return transfers.stream().mapToLong(t -> t.getAmountKrw().longValueExact()).sum();
	}
}
