package com.backpackcorp.backpack.expense.dto;

import java.util.UUID;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

// shareKrw는 CUSTOM(개별 입력)에서만 쓴다. 다른 방식에서는 서버가 계산하므로 보내도 무시한다
public record ExpenseShareRequest(
	@NotNull(message = "분담할 멤버를 선택해 주세요.")
	UUID memberId,

	@PositiveOrZero(message = "분담 금액은 0원 이상이어야 해요.")
	Long shareKrw
) {
}
