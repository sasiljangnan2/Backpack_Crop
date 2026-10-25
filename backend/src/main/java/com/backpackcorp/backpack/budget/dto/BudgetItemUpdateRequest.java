package com.backpackcorp.backpack.budget.dto;

import java.math.BigDecimal;

import com.backpackcorp.backpack.expense.domain.ExpenseCategory;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

// 보낸 값만 바뀐다
public record BudgetItemUpdateRequest(
	ExpenseCategory category,

	@Size(min = 1, max = 100, message = "항목 이름은 1~100자로 입력해 주세요.")
	String name,

	@DecimalMin(value = "0", message = "금액은 0 이상이어야 해요.")
	@Digits(integer = 13, fraction = 2, message = "금액은 소수 둘째 자리까지 입력할 수 있어요.")
	BigDecimal amount,

	@Pattern(regexp = "[A-Za-z]{3}", message = "통화 코드는 영문 3자리예요.")
	String currencyCode
) {
}
