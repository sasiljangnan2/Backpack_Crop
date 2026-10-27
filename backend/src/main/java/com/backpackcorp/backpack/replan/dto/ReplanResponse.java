package com.backpackcorp.backpack.replan.dto;

import java.io.Serializable;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.TravelLeg;
import com.backpackcorp.backpack.replan.domain.PlanKey;
import com.fasterxml.jackson.annotation.JsonFormat;

// BP-AI-002 · 003 추천 결과. requestId로 30분 안에 적용할 수 있다 (POST .../replan/apply).
//   source  AI: Gemini가 고른 순서 · 장소를 서버가 실제 이동 시간으로 다시 맞춘 안 / RULE: 규칙 기반 추천
//   notice  AI 대신 규칙 기반 추천을 보여 줄 때 그 이유
public record ReplanResponse(
	UUID requestId,
	Source source,
	String notice,
	Context context,
	List<Plan> plans
) implements Serializable {

	public enum Source {
		AI,
		RULE
	}

	// "AI가 읽은 현재 상황"
	public record Context(
		String currentPlace,
		boolean currentPlaceFromGps,
		@JsonFormat(pattern = "HH:mm") LocalTime now,
		@JsonFormat(pattern = "HH:mm") LocalTime windowStart,
		@JsonFormat(pattern = "HH:mm") LocalTime windowEnd,
		int doneCount,
		int delayMin,
		Anchor anchor
	) implements Serializable {
	}

	// 다시 짤 구간 바로 뒤의 일정 (보통 고정 일정). 재구성으로 바뀌지 않는다
	public record Anchor(
		UUID scheduleId,
		String title,
		String placeText,
		@JsonFormat(pattern = "HH:mm") LocalTime startTime,
		boolean isLocked,
		long minutesUntil
	) implements Serializable {
	}

	public record Plan(
		PlanKey key,
		String label,
		String reason,
		@JsonFormat(pattern = "HH:mm") LocalTime startTime,
		@JsonFormat(pattern = "HH:mm") LocalTime endTime,
		int travelMin,
		// 마지막 일정 뒤 고정 일정까지 남는 시간. 고정 일정이 없으면 null
		Integer slackMin,
		int conditionRate,
		List<Item> items,
		// 마지막 일정 → 고정 일정 이동
		TravelLeg travelToAnchor,
		List<Dropped> dropped
	) implements Serializable {
	}

	// scheduleId가 null이면 새로 넣는 일정 (휴식 · AI가 추천한 장소)
	public record Item(
		UUID scheduleId,
		String title,
		String placeText,
		Double lat,
		Double lng,
		PlaceCategory category,
		@JsonFormat(pattern = "HH:mm") LocalTime startTime,
		@JsonFormat(pattern = "HH:mm") LocalTime endTime,
		int stayMin,
		TravelLeg travelBefore,
		boolean isNew
	) implements Serializable {
	}

	// 이 안을 적용하면 빠지는(지워지는) 일정
	public record Dropped(
		UUID scheduleId,
		String title
	) implements Serializable {
	}
}
