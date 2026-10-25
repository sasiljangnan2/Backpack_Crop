package com.backpackcorp.backpack.expense.dto;

import java.math.BigDecimal;

import com.backpackcorp.backpack.expense.domain.ExpenseCategory;

// 분류별 원화 합계 (JPQL 생성자 표현식용)
public record CategoryAmountDto(
	ExpenseCategory category,
	BigDecimal amountKrw
) {

	public long amount() {
		return amountKrw == null ? 0 : amountKrw.longValueExact();
	}
}
