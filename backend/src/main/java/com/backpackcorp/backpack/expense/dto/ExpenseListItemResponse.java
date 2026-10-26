package com.backpackcorp.backpack.expense.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import com.backpackcorp.backpack.expense.domain.Expense;
import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.domain.RateMode;

// 지출 목록의 한 줄. myShareKrw는 내가 부담할 금액 (분담 대상이 아니면 0).
// creator가 payer와 다르면 다른 사람이 대신 입력한 지출이다 (대리 입력 배지)
public record ExpenseListItemResponse(
	UUID id,
	String title,
	ExpenseCategory category,
	LocalDate paidDate,
	RateMode rateMode,
	BigDecimal amountLocal,
	long amountKrw,
	MemberRef payer,
	MemberRef creator,
	boolean isPaidByMe,
	long myShareKrw,
	Instant createdAt
) {

	public static ExpenseListItemResponse of(Expense expense, UUID myMemberId, long myShareKrw) {
		return new ExpenseListItemResponse(expense.getId(), expense.getTitle(), expense.getCategory(),
			expense.getPaidDate(), expense.getRateMode(), expense.getAmountLocal(),
			expense.getAmountKrw().longValueExact(), MemberRef.from(expense.getPayer()),
			MemberRef.from(expense.getCreator()), expense.getPayer().getId().equals(myMemberId), myShareKrw,
			expense.getCreatedAt());
	}
}
