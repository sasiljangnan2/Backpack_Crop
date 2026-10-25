package com.backpackcorp.backpack.settlement.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.dto.MemberRef;

// BP-ST-002 계산 근거 + 홈의 "공동 지출 · 지금까지 내 정산" 카드.
// balanceKrw = paidKrw − shareKrw. expenses의 balanceKrw를 모두 더하면 같은 값이 된다
public record MySettlementResponse(
	MemberRef me,
	long paidKrw,
	long shareKrw,
	long balanceKrw,
	SettlementStatus status,
	long tripTotalKrw,
	long expenseCount,
	List<MyTransferResponse> transfers,
	List<ExpenseLine> expenses,
	Instant calculatedAt
) {

	// direction: SEND면 내가 counterpart에게 보내고, RECEIVE면 counterpart에게서 받는다
	public record MyTransferResponse(
		Direction direction,
		MemberRef counterpart,
		long amountKrw
	) {
	}

	public enum Direction {
		SEND,
		RECEIVE
	}

	// 지출 한 건이 내 잔액에 준 영향. paidKrw는 내가 결제했으면 지출 금액, 아니면 0
	public record ExpenseLine(
		UUID expenseId,
		String title,
		ExpenseCategory category,
		LocalDate paidDate,
		long amountKrw,
		MemberRef payer,
		boolean isPaidByMe,
		long paidKrw,
		long myShareKrw,
		long balanceKrw
	) {
	}
}
