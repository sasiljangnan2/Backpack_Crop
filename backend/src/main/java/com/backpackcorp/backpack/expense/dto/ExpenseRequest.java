package com.backpackcorp.backpack.expense.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.domain.RateMode;
import com.backpackcorp.backpack.expense.domain.SplitMethod;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

// 지출 등록·미리보기 요청.
// 금액: rateMode가 KRW면 amountKrw, 그 외에는 amountLocal(여행 통화). MANUAL은 manualRate도 필요하다.
// 분담: items에 항목과 분담자를 담는다. 균등 분담(EQUAL)은 items 대신 memberIds만 보내도 된다.
// version: 수정(PUT)할 때만 필요하다. 조회 때 받은 값을 그대로 보낸다
public record ExpenseRequest(
	@NotNull(message = "결제자를 선택해 주세요.")
	UUID payerMemberId,

	@NotBlank(message = "내용을 입력해 주세요.")
	@Size(max = 100, message = "내용은 100자 이하로 입력해 주세요.")
	String title,

	@NotNull(message = "분류를 선택해 주세요.")
	ExpenseCategory category,

	@NotNull(message = "결제 날짜를 입력해 주세요.")
	LocalDate paidDate,

	@NotNull(message = "통화·환율 방식을 선택해 주세요.")
	RateMode rateMode,

	@Positive(message = "금액은 0보다 커야 해요.")
	@Digits(integer = 13, fraction = 2, message = "금액은 소수 둘째 자리까지 입력할 수 있어요.")
	BigDecimal amountLocal,

	@Positive(message = "환율은 0보다 커야 해요.")
	@Digits(integer = 9, fraction = 6, message = "환율은 소수 여섯째 자리까지 입력할 수 있어요.")
	BigDecimal manualRate,

	@Positive(message = "금액은 0보다 커야 해요.")
	@Max(value = 999_999_999_999L, message = "금액이 너무 커요.")
	Long amountKrw,

	@NotNull(message = "분담 방식을 선택해 주세요.")
	SplitMethod splitMethod,

	@Size(max = 100)
	List<UUID> memberIds,

	@Size(max = 50, message = "항목은 50개까지 입력할 수 있어요.")
	List<@Valid ExpenseItemRequest> items,

	Integer version
) {
}
