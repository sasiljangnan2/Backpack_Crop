package com.backpackcorp.backpack.settlement.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.expense.dto.MemberRef;

// BP-ST-003 공유한 정산 (그 시점의 송금 목록 스냅샷). 이후 지출이 바뀌어도 이 목록은 바뀌지 않는다
public record SettlementShareResponse(
	UUID id,
	MemberRef sharedBy,
	Instant createdAt,
	long transferTotalKrw,
	List<TransferResponse> transfers
) {

	public record TransferResponse(
		UUID id,
		MemberRef from,
		MemberRef to,
		long amountKrw
	) {
	}

	// 공유 이력의 한 줄
	public record Summary(
		UUID id,
		MemberRef sharedBy,
		Instant createdAt,
		int transferCount,
		long transferTotalKrw
	) {
	}
}
