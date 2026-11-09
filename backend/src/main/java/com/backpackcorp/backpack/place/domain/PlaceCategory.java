package com.backpackcorp.backpack.place.domain;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

// 장소 분류. Google 장소 종류 또는 OpenStreetMap 태그(class=type)에서 정하고, 일정 재구성 조건(먹거리 · 실내 · 휴식)을 판단할 때 쓴다
public enum PlaceCategory {
	FOOD("맛집"),
	CAFE("카페"),
	SHOPPING("쇼핑"),
	SIGHT("관광"),
	PARK("공원"),
	LODGING("숙소"),
	TRANSPORT("교통"),
	ETC("기타");

	private static final Set<String> FOOD_TYPES = Set.of("restaurant", "fast_food", "food_court", "bar", "pub",
		"biergarten", "ice_cream", "marketplace");
	private static final Set<String> SIGHT_TYPES = Set.of("attraction", "museum", "gallery", "viewpoint", "zoo",
		"aquarium", "theme_park", "artwork", "castle", "monument", "memorial", "ruins", "place_of_worship", "temple",
		"shrine", "theatre", "cinema", "arts_centre");
	private static final Set<String> PARK_TYPES = Set.of("park", "garden", "nature_reserve", "beach", "playground");
	private static final Set<String> LODGING_TYPES = Set.of("hotel", "hostel", "guest_house", "motel", "apartment");
	private static final Set<String> TRANSPORT_TYPES = Set.of("station", "halt", "subway_entrance", "bus_station",
		"aerodrome", "terminal", "ferry_terminal");

	private final String label;

	PlaceCategory(String label) {
		this.label = label;
	}

	public String label() {
		return label;
	}

	// Nominatim의 category(class) · type. 예: amenity=restaurant, shop=department_store, tourism=museum
	public static PlaceCategory fromOsm(String osmClass, String osmType) {
		String cls = osmClass == null ? "" : osmClass;
		String type = osmType == null ? "" : osmType;
		if ("cafe".equals(type)) {
			return CAFE;
		}
		if (FOOD_TYPES.contains(type)) {
			return FOOD;
		}
		if ("shop".equals(cls) || "mall".equals(type) || "department_store".equals(type)) {
			return SHOPPING;
		}
		if (LODGING_TYPES.contains(type) && "tourism".equals(cls)) {
			return LODGING;
		}
		if (PARK_TYPES.contains(type)) {
			return PARK;
		}
		if ("historic".equals(cls) || SIGHT_TYPES.contains(type)) {
			return SIGHT;
		}
		if ("railway".equals(cls) || "aeroway".equals(cls) || TRANSPORT_TYPES.contains(type)) {
			return TRANSPORT;
		}
		return ETC;
	}

	// Google Places의 primaryType · types. 예: restaurant, cafe, department_store, tourist_attraction, park
	public static PlaceCategory fromGoogle(String primaryType, List<String> types) {
		List<String> all = new ArrayList<>();
		if (primaryType != null) {
			all.add(primaryType);
		}
		all.addAll(types);
		for (String type : all) {
			PlaceCategory category = googleType(type);
			if (category != ETC) {
				return category;
			}
		}
		return ETC;
	}

	private static PlaceCategory googleType(String type) {
		if (type.equals("cafe") || type.equals("coffee_shop") || type.equals("bakery") || type.equals("tea_house")) {
			return CAFE;
		}
		if (type.endsWith("_restaurant") || type.equals("restaurant") || type.equals("food") || type.equals("bar")
			|| type.equals("meal_takeaway") || type.equals("food_court") || type.equals("market")) {
			return FOOD;
		}
		if (type.equals("shopping_mall") || type.equals("department_store") || type.endsWith("_store")
			|| type.equals("store")) {
			return SHOPPING;
		}
		if (type.equals("lodging") || type.equals("hotel") || type.equals("hostel") || type.equals("guest_house")) {
			return LODGING;
		}
		if (type.equals("park") || type.equals("garden") || type.equals("national_park") || type.equals("beach")) {
			return PARK;
		}
		if (type.endsWith("_station") || type.equals("airport") || type.equals("transit_station")) {
			return TRANSPORT;
		}
		if (type.equals("tourist_attraction") || type.equals("museum") || type.equals("art_gallery")
			|| type.equals("historical_landmark") || type.equals("observation_deck") || type.equals("amusement_park")
			|| type.equals("zoo") || type.equals("aquarium") || type.equals("place_of_worship")
			|| type.equals("monument") || type.equals("castle")) {
			return SIGHT;
		}
		return ETC;
	}

	// "먹거리 포함"
	public boolean isFood() {
		return this == FOOD || this == CAFE;
	}

	// "실내 위주". 공원 · 관광지(야외가 많다) · 기타는 실내로 보지 않는다
	public boolean isIndoor() {
		return this == FOOD || this == CAFE || this == SHOPPING || this == LODGING;
	}

	// "휴식 필요"
	public boolean isRest() {
		return this == CAFE || this == PARK;
	}
}
