package com.backpackcorp.backpack.place.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.PlaceResponse;
import com.backpackcorp.backpack.place.dto.TravelLeg;

class GoogleMapsClientTest {

	private static final LatLng NAMBA = new LatLng(34.6655, 135.5066);
	private static final LatLng UMEDA = new LatLng(34.7053, 135.4896);

	@Test
	void 구글_장소_검색_결과를_이름_주소_분류로_바꾼다() {
		List<PlaceResponse> places = GoogleMapsClient.parsePlaces(Map.of("places", List.of(
			Map.of("displayName", Map.of("text", "구로몬 시장"), "shortFormattedAddress", "닛폰바시 2초메",
				"location", Map.of("latitude", 34.6655, "longitude", 135.5066), "primaryType", "market",
				"types", List.of("market", "point_of_interest")),
			Map.of("displayName", Map.of("text", "좌표 없음")))));

		assertThat(places).singleElement().satisfies(p -> {
			assertThat(p.name()).isEqualTo("구로몬 시장");
			assertThat(p.address()).isEqualTo("닛폰바시 2초메");
			assertThat(p.category()).isEqualTo(PlaceCategory.FOOD);
		});
		assertThat(GoogleMapsClient.parsePlaces(Map.of())).isEmpty();
	}

	@Test
	void 구글_경로_표를_읽고_경로가_없는_칸은_비워_둔다() {
		OsmClient.Matrix matrix = GoogleMapsClient.parseMatrix(2, List.of(
			Map.of("originIndex", 0, "destinationIndex", 1, "duration", "160s", "distanceMeters", 822,
				"condition", "ROUTE_EXISTS"),
			Map.of("originIndex", 1, "destinationIndex", 0, "condition", "ROUTE_NOT_FOUND"),
			Map.of("originIndex", 0, "destinationIndex", 0, "duration", "0s")));

		assertThat(matrix.durationsSec()[0][1]).isEqualTo(160.0);
		assertThat(matrix.distancesM()[0][1]).isEqualTo(822.0);
		assertThat(matrix.durationsSec()[1][0]).isNull();
		assertThat(matrix.durationsSec()[0][0]).isZero();
	}

	@Test
	void 걸어서_20분이_넘으면_구글_대중교통_시간을_쓴다() {
		GoogleMapsClient google = mock(GoogleMapsClient.class);
		OsmClient osm = mock(OsmClient.class);
		when(google.routeMatrix(eq("WALK"), any())).thenReturn(new OsmClient.Matrix(
			new Double[][] {{0.0, 3000.0}, {3000.0, 0.0}}, new Double[][] {{0.0, 4100.0}, {4100.0, 0.0}}));
		when(google.routeMatrix(eq("TRANSIT"), any())).thenReturn(new OsmClient.Matrix(
			new Double[][] {{0.0, 900.0}, {960.0, 0.0}}, new Double[][] {{0.0, 4500.0}, {4500.0, 0.0}}));

		TravelLeg leg = new TravelService(google, osm).leg(NAMBA, UMEDA);

		assertThat(leg.mode()).isEqualTo(TravelLeg.TravelMode.TRANSIT);
		assertThat(leg.minutes()).isEqualTo(15);
		assertThat(leg.walkMin()).isEqualTo(50);
		assertThat(leg.estimated()).isFalse();
		// 구글 도보 경로가 있으면 OpenStreetMap은 부르지 않는다
		verify(osm, never()).walkTable(anyString());
	}

	@Test
	void 대중교통이_걷기보다_빠르지_않으면_대중교통으로_보지_않는다() {
		// 대중교통이 없는 곳에서 구글은 걷기만 하는 경로를 대중교통으로 돌려준다
		TravelLeg leg = TravelLeg.of(4100, 58, 15, 58, false);

		assertThat(leg.mode()).isEqualTo(TravelLeg.TravelMode.DRIVE);
		assertThat(leg.transitMin()).isNull();
	}

	@Test
	void 구글이_실패하면_OpenStreetMap_도보_경로를_쓴다() {
		GoogleMapsClient google = mock(GoogleMapsClient.class);
		OsmClient osm = mock(OsmClient.class);
		when(osm.walkTable(anyString())).thenReturn(new OsmClient.Matrix(
			new Double[][] {{0.0, 480.0}, {480.0, 0.0}}, new Double[][] {{0.0, 650.0}, {650.0, 0.0}}));

		TravelLeg leg = new TravelService(google, osm).leg(NAMBA, UMEDA);

		assertThat(leg.mode()).isEqualTo(TravelLeg.TravelMode.WALK);
		assertThat(leg.minutes()).isEqualTo(8);
		assertThat(leg.transitMin()).isNull();
	}

	@Test
	void 구글_장소_종류로_분류를_정한다() {
		assertThat(PlaceCategory.fromGoogle("ramen_restaurant", List.of())).isEqualTo(PlaceCategory.FOOD);
		assertThat(PlaceCategory.fromGoogle("coffee_shop", List.of())).isEqualTo(PlaceCategory.CAFE);
		assertThat(PlaceCategory.fromGoogle(null, List.of("point_of_interest", "department_store")))
			.isEqualTo(PlaceCategory.SHOPPING);
		assertThat(PlaceCategory.fromGoogle("observation_deck", List.of())).isEqualTo(PlaceCategory.SIGHT);
		assertThat(PlaceCategory.fromGoogle("subway_station", List.of())).isEqualTo(PlaceCategory.TRANSPORT);
		assertThat(PlaceCategory.fromGoogle("point_of_interest", List.of())).isEqualTo(PlaceCategory.ETC);
	}
}
