package com.backpackcorp.backpack.expense.dto;

import java.math.BigDecimal;

// 지출 건수와 원화 합계 (JPQL 생성자 표현식용). 지출이 없으면 합계가 null로 온다
public record ExpenseTotalsDto(
	Long count,
	BigDecimal totalKrw
) {

	public long countValue() {
		return count == null ? 0 : count;
	}

	public long totalValue() {
		return totalKrw == null ? 0 : totalKrw.longValueExact();
	}
}
