package com.backpackcorp.backpack.budget.dto;

import java.math.BigDecimal;

import com.backpackcorp.backpack.expense.domain.ExpenseCategory;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

// currencyCode는 KRW 또는 여행 통화
public record BudgetItemRequest(
	@NotNull(message = "분류를 선택해 주세요.")
	ExpenseCategory category,

	@NotBlank(message = "항목 이름을 입력해 주세요.")
	@Size(max = 100, message = "항목 이름은 100자 이하로 입력해 주세요.")
	String name,

	@NotNull(message = "금액을 입력해 주세요.")
	@DecimalMin(value = "0", message = "금액은 0 이상이어야 해요.")
	@Digits(integer = 13, fraction = 2, message = "금액은 소수 둘째 자리까지 입력할 수 있어요.")
	BigDecimal amount,

	@NotBlank(message = "통화를 선택해 주세요.")
	@Pattern(regexp = "[A-Za-z]{3}", message = "통화 코드는 영문 3자리예요.")
	String currencyCode
) {
}
