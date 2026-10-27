package com.backpackcorp.backpack.replan.domain;

// BP-AI-003 추천 3안의 기준
public enum PlanKey {
	CONDITION("조건 일치 우선"),
	MIN_TRAVEL("이동 최소"),
	SLACK("시간 여유 우선");

	private final String label;

	PlanKey(String label) {
		this.label = label;
	}

	public String label() {
		return label;
	}
}
