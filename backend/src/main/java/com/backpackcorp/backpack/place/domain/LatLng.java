package com.backpackcorp.backpack.place.domain;

import java.io.Serializable;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Locale;

// 위도 · 경도. 캐시 키와 외부 API 요청에는 소수점 5자리(약 1m)로 맞춘 값을 쓴다
public record LatLng(double lat, double lng) implements Serializable {

	private static final double EARTH_RADIUS_M = 6_371_000;

	public static LatLng of(BigDecimal lat, BigDecimal lng) {
		return lat == null || lng == null ? null : new LatLng(lat.doubleValue(), lng.doubleValue());
	}

	public static BigDecimal scaled(double value) {
		return BigDecimal.valueOf(value).setScale(6, RoundingMode.HALF_UP);
	}

	// OSRM 경로 문법: "경도,위도"
	public String osrm() {
		return String.format(Locale.ROOT, "%.5f,%.5f", lng, lat);
	}

	// 두 점 사이 직선거리(m)
	public double distanceTo(LatLng other) {
		double dLat = Math.toRadians(other.lat - lat);
		double dLng = Math.toRadians(other.lng - lng);
		double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
			+ Math.cos(Math.toRadians(lat)) * Math.cos(Math.toRadians(other.lat))
			* Math.sin(dLng / 2) * Math.sin(dLng / 2);
		return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a));
	}
}
