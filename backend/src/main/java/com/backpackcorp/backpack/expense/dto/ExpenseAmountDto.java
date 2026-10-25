package com.backpackcorp.backpack.expense.dto;

import java.math.BigDecimal;
import java.util.UUID;

// 지출별 원화 합계 (JPQL 생성자 표현식용)
public record ExpenseAmountDto(
	UUID expenseId,
	BigDecimal amountKrw
) {

	public long amount() {
		return amountKrw == null ? 0 : amountKrw.longValueExact();
	}
}
