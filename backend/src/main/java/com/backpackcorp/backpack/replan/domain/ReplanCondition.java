package com.backpackcorp.backpack.replan.domain;

import java.util.List;

import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.TravelLeg;
import com.backpackcorp.backpack.replan.dto.ReplanResponse;

// BP-AI-002 조건 칩 (복수 선택)
public enum ReplanCondition {
	WALK_15("도보 15분 이내"),
	REST("휴식 필요"),
	INDOOR("실내 위주"),
	FOOD("먹거리 포함");

	public static final int WALK_LIMIT_MIN = 15;

	private final String label;

	ReplanCondition(String label) {
		this.label = label;
	}

	public String label() {
		return label;
	}

	// 일정 하나가 이 조건에 맞는지 (도보 조건은 이동 구간으로 본다)
	public boolean matches(PlaceCategory category) {
		if (category == null) {
			return false;
		}
		return switch (this) {
			case REST -> category.isRest();
			case INDOOR -> category.isIndoor();
			case FOOD -> category.isFood();
			case WALK_15 -> false;
		};
	}

	// 추천안 전체가 이 조건을 지키는지. legs는 마지막 일정 → 고정 일정 이동까지 포함한다
	public boolean satisfiedBy(List<ReplanResponse.Item> items, List<TravelLeg> legs) {
		return switch (this) {
			case WALK_15 -> legs.stream().allMatch(leg -> leg.walkMin() <= WALK_LIMIT_MIN);
			case REST, FOOD -> items.stream().anyMatch(item -> matches(item.category()));
			// 2/3 이상이 실내
			case INDOOR -> !items.isEmpty()
				&& items.stream().filter(item -> matches(item.category())).count() * 3 >= items.size() * 2L;
		};
	}
}
