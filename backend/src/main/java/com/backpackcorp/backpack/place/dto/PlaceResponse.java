package com.backpackcorp.backpack.place.dto;

import java.io.Serializable;

import com.backpackcorp.backpack.place.domain.PlaceCategory;

// 장소 검색 · 현재 위치 결과. name은 한국어 이름이 있으면 한국어, 없으면 현지 이름.
// source: GOOGLE(Google Places) 또는 OSM(OpenStreetMap). 앱이 검색 결과 밑에 출처를 표시한다
public record PlaceResponse(
	String name,
	String address,
	double lat,
	double lng,
	PlaceCategory category,
	String source
) implements Serializable {

	public static final String GOOGLE = "GOOGLE";
	public static final String OSM = "OSM";
}
