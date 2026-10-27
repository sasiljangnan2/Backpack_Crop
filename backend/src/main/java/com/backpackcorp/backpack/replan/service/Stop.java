package com.backpackcorp.backpack.replan.service;

import java.util.UUID;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;

// 재구성에서 다루는 일정 하나.
//   id       기존 일정. null이면 새로 넣는 일정 (휴식 · AI가 추천한 장소)
//   place    좌표. 없으면 이동 시간을 어림값(10분)으로 본다
//   nearby   바로 앞 일정과 같은 곳 (이동 0분). 규칙 기반 추천이 넣는 "잠깐 쉬어 가기"
public record Stop(
	UUID id,
	String title,
	String placeText,
	LatLng place,
	PlaceCategory category,
	int stayMin,
	boolean nearby
) {

	public boolean isNew() {
		return id == null;
	}

	public Stop withStay(int minutes) {
		return new Stop(id, title, placeText, place, category, minutes, nearby);
	}
}
