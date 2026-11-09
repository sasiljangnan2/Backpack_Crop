package com.backpackcorp.backpack.place.service;

import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.dto.PlaceResponse;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

// 장소 검색 (BP-SC-002 장소 입력, BP-AI-002 위치 직접 입력) · 현재 위치의 장소 이름.
// 구글 키가 있으면 Google Places, 없거나 실패하면 OpenStreetMap(Nominatim)으로 찾는다
@Service
public class PlaceService {

	// 근처를 먼저 보여 줄 범위 (위도 · 경도 ±). 현재 위치 기준은 좁게, 여행지 기준은 도시 하나쯤
	private static final double NEAR_SPAN = 0.15;
	private static final double CITY_SPAN = 0.4;
	// 같은 범위를 구글 검색 반경(m)으로
	private static final int NEAR_RADIUS_M = 15_000;
	private static final int CITY_RADIUS_M = 40_000;

	private final GoogleMapsClient google;
	private final OsmClient osm;
	private final TripMemberGuard tripMemberGuard;
	private final TransactionTemplate readTransaction;

	public PlaceService(GoogleMapsClient google, OsmClient osm, TripMemberGuard tripMemberGuard,
		PlatformTransactionManager transactionManager) {
		this.google = google;
		this.osm = osm;
		this.tripMemberGuard = tripMemberGuard;
		this.readTransaction = new TransactionTemplate(transactionManager);
		this.readTransaction.setReadOnly(true);
	}

	// near가 있으면 그 근처, tripId가 있으면 여행지 근처를 먼저. 검색 서버에 닿지 못하면 빈 목록.
	// 외부 검색을 기다리는 동안 DB 연결을 잡지 않도록 여행지 이름만 짧은 트랜잭션에서 읽는다
	public List<PlaceResponse> search(String query, UUID tripId, LatLng near, UUID userId) {
		LatLng center = near;
		boolean city = false;
		if (center == null && tripId != null) {
			String destination = readTransaction.execute(
				status -> tripMemberGuard.requireMember(tripId, userId).getTrip().getDestination());
			center = destinationOf(destination);
			city = true;
		}
		List<PlaceResponse> results = find(query.trim(), center, city ? CITY_RADIUS_M : NEAR_RADIUS_M,
			city ? CITY_SPAN : NEAR_SPAN);
		return results == null ? List.of() : results;
	}

	public PlaceResponse reverse(LatLng point) {
		PlaceResponse place = google.nearest(point);
		return place != null ? place : osm.reverse(point);
	}

	// 여행지 이름("일본 오사카")의 중심 좌표. 검색 결과는 캐시되므로 여행마다 한 번만 묻는다
	LatLng destinationOf(String destination) {
		List<PlaceResponse> found = find(destination, null, 0, 0);
		if (found == null || found.isEmpty()) {
			return null;
		}
		return new LatLng(found.getFirst().lat(), found.getFirst().lng());
	}

	// 근처에서 이름으로 장소 하나 찾기 (AI가 추천한 새 장소의 좌표를 확인할 때)
	public PlaceResponse findNear(String name, LatLng near) {
		List<PlaceResponse> found = find(name, near, 5_000, NEAR_SPAN / 3);
		if (found == null) {
			return null;
		}
		return found.stream()
			.filter(p -> near.distanceTo(new LatLng(p.lat(), p.lng())) < 5_000)
			.findFirst()
			.orElse(null);
	}

	// 구글 → (없거나 실패하면) OpenStreetMap
	private List<PlaceResponse> find(String query, LatLng center, int radiusM, double span) {
		List<PlaceResponse> found = google.search(query, center, radiusM);
		if (found != null) {
			return found;
		}
		return osm.search(query, center == null ? null : viewbox(center, span));
	}

	static String viewbox(LatLng center, double span) {
		return String.format(Locale.ROOT, "%.4f,%.4f,%.4f,%.4f", center.lng() - span, center.lat() + span,
			center.lng() + span, center.lat() - span);
	}
}
