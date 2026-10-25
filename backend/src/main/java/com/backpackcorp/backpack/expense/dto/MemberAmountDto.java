package com.backpackcorp.backpack.expense.dto;

import java.math.BigDecimal;
import java.util.UUID;

// 멤버별 원화 합계 (JPQL 생성자 표현식용)
public record MemberAmountDto(
	UUID memberId,
	BigDecimal amountKrw
) {

	public long amount() {
		return amountKrw == null ? 0 : amountKrw.longValueExact();
	}
}
