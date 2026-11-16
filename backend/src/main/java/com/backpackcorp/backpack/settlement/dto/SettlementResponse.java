package com.backpackcorp.backpack.settlement.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.expense.dto.MemberRef;

// BP-ST-001 최종 정산. 저장하지 않고 요청 때마다 지출에서 계산한다.
// transferTotalKrw는 받을 돈(양수 잔액)의 합과 항상 같다.
// directTransferCount: 지출마다 결제자에게 바로 보낸다면 필요한 송금 건수 ("송금 14건 → 4건으로 줄였어요")
public record SettlementResponse(
	long totalKrw,
	long expenseCount,
	long transferTotalKrw,
	long directTransferCount,
	List<MemberResponse> members,
	List<TransferResponse> transfers,
	FundSummary fund,
	Instant calculatedAt
) {

	// 공금을 쓰지 않는 여행이면 null. 남은 공금은 transfers에 "공금 → 멤버"로 나온다
	public record FundSummary(long collectedKrw, long spentKrw, long remainingKrw) {
	}

	// hasLeft: 여행을 나간 멤버. 나가기 전 지출이 남아 있으면 정산에 계속 나온다.
	// paidKrw: 직접 결제한 돈 + 공금에 모은 돈(contributedKrw)
	public record MemberResponse(
		UUID memberId,
		String name,
		boolean isMe,
		boolean hasLeft,
		long paidKrw,
		long contributedKrw,
		long shareKrw,
		long balanceKrw,
		SettlementStatus status
	) {
	}

	public record TransferResponse(
		MemberRef from,
		MemberRef to,
		long amountKrw
	) {
	}
}
