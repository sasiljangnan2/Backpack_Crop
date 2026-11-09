package com.backpackcorp.backpack.place.service;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.PlaceResponse;

import lombok.extern.slf4j.Slf4j;

// Google Maps Platform (서버 키 GOOGLE_MAPS_API_KEY).
//   Places API (New) Text Search: 장소 검색 · Nearby Search: 지금 있는 곳의 장소 이름
//   Routes API Compute Route Matrix: 도보 · 대중교통 시간
// 키가 없으면 쓰지 않고(enabled() = false), 실패하면 null을 돌려준다. 부르는 쪽이 OpenStreetMap으로 대신한다.
// 월 무료 사용량이 있지만 결제 계정이 필요하다 (docs/google-maps.md). 같은 요청이 반복되지 않게 결과를 오래 캐시한다
@Slf4j
@Component
public class GoogleMapsClient {

	private static final ParameterizedTypeReference<Map<String, Object>> JSON = new ParameterizedTypeReference<>() {
	};
	private static final ParameterizedTypeReference<List<Map<String, Object>>> JSON_LIST =
		new ParameterizedTypeReference<>() {
		};
	private static final String PLACE_FIELDS =
		"places.displayName,places.formattedAddress,places.shortFormattedAddress,places.location,places.primaryType,places.types";
	// 대중교통 경로 표는 출발 × 도착이 100칸을 넘을 수 없다
	static final int MAX_TRANSIT_POINTS = 10;

	private final RestClient places;
	private final RestClient routes;
	private final String apiKey;

	public GoogleMapsClient(
		@Value("${google.maps.api-key:}") String apiKey,
		@Value("${google.maps.places-url:https://places.googleapis.com/v1}") String placesUrl,
		@Value("${google.maps.routes-url:https://routes.googleapis.com}") String routesUrl) {
		this.apiKey = apiKey == null ? "" : apiKey.trim();
		this.places = client(placesUrl);
		this.routes = client(routesUrl);
	}

	public boolean enabled() {
		return !apiKey.isEmpty();
	}

	// near가 있으면 그 둘레 radiusM 안을 먼저 보여 준다
	@Cacheable(cacheNames = "place-search",
		key = "'g|' + #query + '|' + (#near == null ? '-' : #near.toString()) + '|' + #radiusM",
		unless = "#result == null")
	public List<PlaceResponse> search(String query, LatLng near, int radiusM) {
		if (!enabled()) {
			return null;
		}
		Map<String, Object> body = new HashMap<>();
		body.put("textQuery", query);
		body.put("languageCode", "ko");
		body.put("maxResultCount", 8);
		if (near != null) {
			body.put("locationBias", Map.of("circle", circle(near, radiusM)));
		}
		try {
			return parsePlaces(places.post().uri("/places:searchText")
				.header("X-Goog-Api-Key", apiKey)
				.header("X-Goog-FieldMask", PLACE_FIELDS)
				.contentType(MediaType.APPLICATION_JSON)
				.body(body)
				.retrieve()
				.body(JSON));
		} catch (RestClientException e) {
			log.warn("구글 장소 검색 실패: {} - {}", query, e.getMostSpecificCause().toString());
			return null;
		}
	}

	// 그 자리에서 가장 가까운 장소 하나 (반경 100m)
	@Cacheable(cacheNames = "place-reverse", key = "'g|' + T(java.lang.String).format(T(java.util.Locale).ROOT, "
		+ "'%.4f,%.4f', #point.lat(), #point.lng())", unless = "#result == null")
	public PlaceResponse nearest(LatLng point) {
		if (!enabled()) {
			return null;
		}
		Map<String, Object> body = Map.of(
			"locationRestriction", Map.of("circle", circle(point, 100)),
			"maxResultCount", 1,
			"rankPreference", "DISTANCE",
			"languageCode", "ko");
		try {
			List<PlaceResponse> found = parsePlaces(places.post().uri("/places:searchNearby")
				.header("X-Goog-Api-Key", apiKey)
				.header("X-Goog-FieldMask", PLACE_FIELDS)
				.contentType(MediaType.APPLICATION_JSON)
				.body(body)
				.retrieve()
				.body(JSON));
			return found.isEmpty() ? null : found.getFirst();
		} catch (RestClientException e) {
			log.warn("구글 주변 장소 조회 실패: {} - {}", point, e.getMostSpecificCause().toString());
			return null;
		}
	}

	// points[i] → points[j] 시간(초) · 거리(m). mode는 WALK 또는 TRANSIT. 경로가 없는 칸은 null
	@Cacheable(cacheNames = "travel", key = "'g|' + #mode + '|' + #points.toString()",
		unless = "#result == null")
	public OsmClient.Matrix routeMatrix(String mode, List<LatLng> points) {
		if (!enabled() || points.size() < 2 || ("TRANSIT".equals(mode) && points.size() > MAX_TRANSIT_POINTS)) {
			return null;
		}
		List<Map<String, Object>> waypoints = points.stream()
			.map(p -> Map.<String, Object>of("waypoint", Map.of("location", Map.of("latLng",
				Map.of("latitude", p.lat(), "longitude", p.lng())))))
			.toList();
		Map<String, Object> body = Map.of("origins", waypoints, "destinations", waypoints, "travelMode", mode);
		try {
			return parseMatrix(points.size(), routes.post().uri("/distanceMatrix/v2:computeRouteMatrix")
				.header("X-Goog-Api-Key", apiKey)
				.header("X-Goog-FieldMask", "originIndex,destinationIndex,duration,distanceMeters,condition")
				.contentType(MediaType.APPLICATION_JSON)
				.body(body)
				.retrieve()
				.body(JSON_LIST));
		} catch (RestClientException e) {
			log.warn("구글 경로 표({}) 실패: {}", mode, e.getMostSpecificCause().toString());
			return null;
		}
	}

	@SuppressWarnings("unchecked")
	static List<PlaceResponse> parsePlaces(Map<String, Object> body) {
		List<PlaceResponse> out = new ArrayList<>();
		if (body == null || !(body.get("places") instanceof List<?> list)) {
			return out;
		}
		for (Object item : list) {
			Map<String, Object> place = (Map<String, Object>)item;
			if (!(place.get("displayName") instanceof Map<?, ?> name) || !(place.get("location") instanceof Map<?, ?> loc)
				|| !(loc.get("latitude") instanceof Number lat) || !(loc.get("longitude") instanceof Number lng)) {
				continue;
			}
			String address = place.get("shortFormattedAddress") instanceof String s ? s
				: place.get("formattedAddress") instanceof String f ? f : "";
			List<String> types = place.get("types") instanceof List<?> t
				? t.stream().map(String::valueOf).toList() : List.of();
			out.add(new PlaceResponse(String.valueOf(name.get("text")), address, lat.doubleValue(), lng.doubleValue(),
				PlaceCategory.fromGoogle(place.get("primaryType") instanceof String p ? p : null, types),
				PlaceResponse.GOOGLE));
		}
		return out;
	}

	// 응답은 칸마다 한 줄: {"originIndex":0,"destinationIndex":1,"duration":"160s","distanceMeters":822,
	// "condition":"ROUTE_EXISTS"}
	static OsmClient.Matrix parseMatrix(int n, List<Map<String, Object>> rows) {
		if (rows == null) {
			return null;
		}
		Double[][] durations = new Double[n][n];
		Double[][] distances = new Double[n][n];
		for (Map<String, Object> row : rows) {
			if (!(row.get("originIndex") instanceof Number i) || !(row.get("destinationIndex") instanceof Number j)
				|| i.intValue() >= n || j.intValue() >= n) {
				continue;
			}
			// 같은 곳은 originIndex == destinationIndex, 대중교통이 없는 칸은 condition이 ROUTE_NOT_FOUND
			if (!"ROUTE_EXISTS".equals(row.get("condition")) && i.intValue() != j.intValue()) {
				continue;
			}
			durations[i.intValue()][j.intValue()] = seconds(row.get("duration"));
			distances[i.intValue()][j.intValue()] = row.get("distanceMeters") instanceof Number d
				? d.doubleValue() : 0.0;
		}
		return new OsmClient.Matrix(durations, distances);
	}

	private static Double seconds(Object duration) {
		if (!(duration instanceof String s) || !s.endsWith("s")) {
			return 0.0;
		}
		try {
			return Double.parseDouble(s.substring(0, s.length() - 1));
		} catch (NumberFormatException e) {
			return null;
		}
	}

	private static Map<String, Object> circle(LatLng center, int radiusM) {
		return Map.of("center", Map.of("latitude", center.lat(), "longitude", center.lng()),
			"radius", (double)Math.min(50_000, radiusM));
	}

	private static RestClient client(String baseUrl) {
		HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build();
		JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
		factory.setReadTimeout(Duration.ofSeconds(6));
		return RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
	}
}
