package com.backpackcorp.backpack.replan.dto;

import java.util.UUID;

import com.backpackcorp.backpack.replan.domain.PlanKey;

import jakarta.validation.constraints.NotNull;

// BP-AI-003 "이 안으로 적용"
public record ReplanApplyRequest(
	@NotNull(message = "추천 결과가 없어요. 다시 추천받아 주세요.")
	UUID requestId,

	@NotNull(message = "적용할 안을 골라 주세요.")
	PlanKey planKey
) {
}
