package com.backpackcorp.backpack.fund.dto;

import java.time.LocalDate;
import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

// 공금에 모은 돈. contributedOn을 비우면 오늘
public record FundContributionRequest(
	@NotNull(message = "돈을 낸 사람을 선택해 주세요.")
	UUID memberId,

	@NotNull(message = "금액을 입력해 주세요.")
	@Positive(message = "금액은 0보다 커야 해요.")
	@Max(value = 999_999_999_999L, message = "금액이 너무 커요.")
	Long amountKrw,

	LocalDate contributedOn,

	@Size(max = 100, message = "메모는 100자 이하로 입력해 주세요.")
	String memo
) {
}
