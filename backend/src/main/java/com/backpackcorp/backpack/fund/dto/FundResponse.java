package com.backpackcorp.backpack.fund.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.expense.dto.MemberRef;

// 공금 현황. remainingKrw = collectedKrw - spentKrw (공금에서 낸 지출)
// members: 멤버별로 모은 돈 (아직 안 낸 멤버는 0). contributions: 최근 모은 순
public record FundResponse(
	long collectedKrw,
	long spentKrw,
	long remainingKrw,
	List<MemberTotal> members,
	List<Contribution> contributions
) {

	public record MemberTotal(MemberRef member, long contributedKrw) {
	}

	// canEdit: 돈을 낸 사람 · 입력한 사람 · 방장
	public record Contribution(
		UUID id,
		MemberRef member,
		long amountKrw,
		LocalDate contributedOn,
		String memo,
		MemberRef creator,
		boolean canEdit
	) {
	}
}
