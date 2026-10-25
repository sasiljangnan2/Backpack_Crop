package com.backpackcorp.backpack.settlement.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.expense.dto.MemberRef;

// BP-ST-001 최종 정산. 저장하지 않고 요청 때마다 지출에서 계산한다.
// transferTotalKrw는 받을 돈(양수 잔액)의 합과 항상 같다
public record SettlementResponse(
	long totalKrw,
	long expenseCount,
	long transferTotalKrw,
	List<MemberResponse> members,
	List<TransferResponse> transfers,
	Instant calculatedAt
) {

	// hasLeft: 여행을 나간 멤버. 나가기 전 지출이 남아 있으면 정산에 계속 나온다
	public record MemberResponse(
		UUID memberId,
		String name,
		boolean isMe,
		boolean hasLeft,
		long paidKrw,
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
