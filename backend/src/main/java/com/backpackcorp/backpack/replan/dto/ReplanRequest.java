package com.backpackcorp.backpack.replan.dto;

import java.util.List;
import java.util.Set;
import java.util.UUID;

import com.backpackcorp.backpack.replan.domain.ReplanCondition;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

// BP-AI-002 추천 3안 받기.
//   currentPlace  지금 있는 곳 (GPS 또는 직접 고른 장소). 없으면 마지막으로 끝낸 일정의 장소로 본다
//   conditions    조건 칩
//   scheduleIds   다시 짤 일정 (오늘 · 고정이 아님 · 아직 완료 기록이 없음)
public record ReplanRequest(
	@Valid
	CurrentPlace currentPlace,

	Set<ReplanCondition> conditions,

	@NotEmpty(message = "다시 짤 일정을 하나 이상 골라 주세요.")
	@Size(max = 12, message = "한 번에 12개까지 다시 짤 수 있어요.")
	List<UUID> scheduleIds
) {

	public record CurrentPlace(
		@NotBlank(message = "현재 장소 이름이 필요해요.")
		@Size(max = 100)
		String name,

		@DecimalMin("-90") @DecimalMax("90")
		Double lat,

		@DecimalMin("-180") @DecimalMax("180")
		Double lng,

		// 화면의 "GPS" 표시
		boolean fromGps
	) {
	}
}
