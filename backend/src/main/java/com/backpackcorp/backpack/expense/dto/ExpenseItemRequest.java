package com.backpackcorp.backpack.expense.dto;

import java.math.BigDecimal;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

// 금액은 ITEM(항목별)에서만 필요하다. EQUAL·CUSTOM은 항목 1개이고 금액이 총액이다
public record ExpenseItemRequest(
	@Size(max = 100, message = "항목 이름은 100자 이하로 입력해 주세요.")
	String name,

	// 선택. 외국어 영수증에서 읽은 항목 이름의 한국어 번역
	@Size(max = 100, message = "번역은 100자 이하로 입력해 주세요.")
	String nameKo,

	@Positive(message = "금액은 0보다 커야 해요.")
	@Digits(integer = 13, fraction = 2, message = "금액은 소수 둘째 자리까지 입력할 수 있어요.")
	BigDecimal amountLocal,

	@PositiveOrZero(message = "금액은 0원 이상이어야 해요.")
	Long amountKrw,

	@NotEmpty(message = "분담할 사람을 1명 이상 선택해 주세요.")
	@Size(max = 100)
	List<@Valid ExpenseShareRequest> members
) {
}
