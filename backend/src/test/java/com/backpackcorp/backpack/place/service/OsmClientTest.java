package com.backpackcorp.backpack.place.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.PlaceResponse;
import com.backpackcorp.backpack.place.dto.TravelLeg;

class OsmClientTest {

	@Test
	void Nominatim_결과를_이름_동네_분류로_바꾼다() {
		PlaceResponse place = OsmClient.toPlace(Map.of(
			"lat", "34.6655", "lon", "135.5066", "name", "구로몬 시장", "category", "amenity", "type", "marketplace",
			"display_name", "구로몬 시장, 닛폰바시 2초메, 주오구, 오사카시, 오사카부, 일본"));

		assertThat(place.name()).isEqualTo("구로몬 시장");
		assertThat(place.address()).isEqualTo("닛폰바시 2초메, 주오구, 오사카시");
		assertThat(place.category()).isEqualTo(PlaceCategory.FOOD);
		assertThat(place.lat()).isEqualTo(34.6655);
	}

	@Test
	void 이름이_없으면_주소의_첫_부분을_쓴다() {
		PlaceResponse place = OsmClient.toPlace(Map.of("lat", "35.0", "lon", "135.0", "name", "",
			"category", "highway", "type", "residential", "display_name", "센니치마에, 주오구"));

		assertThat(place.name()).isEqualTo("센니치마에");
		assertThat(place.category()).isEqualTo(PlaceCategory.ETC);
	}

	@Test
	void OSRM_표를_읽고_못_가는_칸은_비워_둔다() {
		OsmClient.Matrix matrix = OsmClient.Matrix.parse(Map.of(
			"code", "Ok",
			"durations", List.of(List.of(0, 600.5), java.util.Arrays.asList(610, null)),
			"distances", List.of(List.of(0, 800), List.of(820, 0))));

		assertThat(matrix.durationsSec()[0][1]).isEqualTo(600.5);
		assertThat(matrix.durationsSec()[1][1]).isNull();
		assertThat(OsmClient.Matrix.parse(Map.of("code", "NoRoute"))).isNull();
	}

	@Test
	void 경로_서버가_없으면_직선거리로_어림한다() {
		TravelService travel = new TravelService(new GoogleMapsClient("", "http://x", "http://x"),
			new OsmClient("http://x", "http://x", "test", false));
		LatLng a = new LatLng(34.6655, 135.5066);
		LatLng b = new LatLng(34.6745, 135.5013);

		TravelLeg leg = travel.leg(a, b);

		assertThat(leg.estimated()).isTrue();
		assertThat(leg.mode()).isEqualTo(TravelLeg.TravelMode.WALK);
		assertThat(leg.walkMin()).isBetween(15, 25);
		assertThat(travel.leg(a, a).minutes()).isZero();
	}

	@Test
	void OSM_태그로_분류를_정한다() {
		assertThat(PlaceCategory.fromOsm("amenity", "cafe")).isEqualTo(PlaceCategory.CAFE);
		assertThat(PlaceCategory.fromOsm("shop", "department_store")).isEqualTo(PlaceCategory.SHOPPING);
		assertThat(PlaceCategory.fromOsm("tourism", "museum")).isEqualTo(PlaceCategory.SIGHT);
		assertThat(PlaceCategory.fromOsm("leisure", "park")).isEqualTo(PlaceCategory.PARK);
		assertThat(PlaceCategory.fromOsm("railway", "station")).isEqualTo(PlaceCategory.TRANSPORT);
		assertThat(PlaceCategory.fromOsm("tourism", "hotel")).isEqualTo(PlaceCategory.LODGING);
	}
}
