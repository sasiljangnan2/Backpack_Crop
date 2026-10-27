package com.backpackcorp.backpack.place.service;

import java.io.Serializable;
import java.net.URI;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.PlaceResponse;

import lombok.extern.slf4j.Slf4j;

// OpenStreetMap 기반 무료 공용 서버 (키 · 결제 정보 없음).
//   Nominatim: 장소 검색 · 좌표 → 장소. 사용 정책상 초당 1회, 앱을 알아볼 수 있는 User-Agent, 결과 캐시,
//              입력할 때마다 찾는 자동완성은 금지 (앱은 검색 버튼을 눌렀을 때만 부른다)
//   OSRM (routing.openstreetmap.de): 도보 이동 시간 · 거리. 차 경로 서버는 자주 늦고 429로 막아 쓰지 않는다
//   (차 시간은 TravelService가 도보 경로 거리로 어림한다)
// 장소와 길은 자주 바뀌지 않으므로 결과를 Redis에 오래 캐시한다 (CacheConfig). 실패하면 null을 돌려주고
// 부르는 쪽이 직선거리 어림값으로 대신한다 (NFR-02). 실패한 결과는 캐시하지 않는다
@Slf4j
@Component
public class OsmClient {

	private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(3);
	// 공용 서버가 늦으면 기다리지 않고 직선거리 어림값을 쓴다 (AI 재구성 응답 시간을 지키려고 짧게)
	private static final Duration READ_TIMEOUT = Duration.ofSeconds(5);
	// 초당 1회보다 조금 여유 있게
	private static final long NOMINATIM_INTERVAL_MS = 1100;
	private static final ParameterizedTypeReference<List<Map<String, Object>>> JSON_LIST =
		new ParameterizedTypeReference<>() {
		};
	private static final ParameterizedTypeReference<Map<String, Object>> JSON = new ParameterizedTypeReference<>() {
	};

	private final RestClient nominatim;
	private final RestClient osrmFoot;
	private final String osrmFootUrl;
	private final boolean enabled;
	private final Object nominatimGate = new Object();
	private long nominatimNextAt;

	public OsmClient(
		@Value("${map.nominatim-url}") String nominatimUrl,
		@Value("${map.osrm-foot-url}") String osrmFootUrl,
		@Value("${map.user-agent}") String userAgent,
		@Value("${map.fetch-enabled:true}") boolean enabled) {
		this.nominatim = client(nominatimUrl, userAgent);
		this.osrmFoot = client(osrmFootUrl, userAgent);
		this.osrmFootUrl = osrmFootUrl;
		this.enabled = enabled;
	}

	// viewbox: "서경,북위,동경,남위" (이 근처를 먼저 보여 준다. 밖의 결과도 나온다). 비어 있으면 전 세계
	@Cacheable(cacheNames = "place-search", key = "#query + '|' + #viewbox", unless = "#result == null")
	public List<PlaceResponse> search(String query, String viewbox) {
		if (!enabled) {
			return null;
		}
		try {
			waitForNominatim();
			List<Map<String, Object>> body = nominatim.get()
				.uri(uri -> {
					uri.path("/search")
						.queryParam("q", query)
						.queryParam("format", "jsonv2")
						.queryParam("limit", 8)
						.queryParam("accept-language", "ko,en");
					if (viewbox != null && !viewbox.isBlank()) {
						uri.queryParam("viewbox", viewbox);
					}
					return uri.build();
				})
				.retrieve()
				.body(JSON_LIST);
			if (body == null) {
				return null;
			}
			return body.stream().map(OsmClient::toPlace).filter(p -> p != null)
				.collect(Collectors.toCollection(ArrayList::new));
		} catch (RestClientException e) {
			log.debug("Nominatim 검색 실패: {} - {}", query, e.getMostSpecificCause().toString());
			return null;
		}
	}

	// 좌표 → 가장 가까운 장소. key는 소수점 4자리(약 10m)로 맞춰 같은 자리의 요청을 모은다
	@Cacheable(cacheNames = "place-reverse", key = "T(java.lang.String).format(T(java.util.Locale).ROOT, '%.4f,%.4f', "
		+ "#point.lat(), #point.lng())", unless = "#result == null")
	public PlaceResponse reverse(LatLng point) {
		if (!enabled) {
			return null;
		}
		try {
			waitForNominatim();
			Map<String, Object> body = nominatim.get()
				.uri(uri -> uri.path("/reverse")
					.queryParam("lat", point.lat())
					.queryParam("lon", point.lng())
					.queryParam("format", "jsonv2")
					.queryParam("zoom", 18)
					.queryParam("accept-language", "ko,en")
					.build())
				.retrieve()
				.body(JSON);
			return body == null || body.containsKey("error") ? null : toPlace(body);
		} catch (RestClientException e) {
			log.debug("Nominatim 역지오코딩 실패: {} - {}", point, e.getMostSpecificCause().toString());
			return null;
		}
	}

	// 여러 장소 사이 걸어서 가는 시간(초) · 거리(m) 표
	@Cacheable(cacheNames = "travel", key = "'foot|' + #coordinates", unless = "#result == null")
	public Matrix walkTable(String coordinates) {
		if (!enabled) {
			return null;
		}
		try {
			// "경도,위도;경도,위도"의 , ; 를 인코딩하면 OSRM이 읽지 못한다. 숫자와 , ; . - 뿐이라 그대로 붙인다
			URI uri = URI.create(osrmFootUrl + "/table/v1/driving/" + coordinates
				+ "?annotations=duration,distance");
			Map<String, Object> body = osrmFoot.get()
				.uri(uri)
				.retrieve()
				.body(JSON);
			return Matrix.parse(body);
		} catch (RestClientException e) {
			log.debug("OSRM 도보 시간 조회 실패: {}", e.getMostSpecificCause().toString());
			return null;
		}
	}

	private void waitForNominatim() {
		synchronized (nominatimGate) {
			long wait = nominatimNextAt - System.currentTimeMillis();
			if (wait > 0) {
				try {
					Thread.sleep(wait);
				} catch (InterruptedException e) {
					Thread.currentThread().interrupt();
				}
			}
			nominatimNextAt = System.currentTimeMillis() + NOMINATIM_INTERVAL_MS;
		}
	}

	static PlaceResponse toPlace(Map<String, Object> row) {
		try {
			double lat = Double.parseDouble(String.valueOf(row.get("lat")));
			double lng = Double.parseDouble(String.valueOf(row.get("lon")));
			String display = String.valueOf(row.getOrDefault("display_name", ""));
			List<String> parts = Arrays.stream(display.split(",")).map(String::trim).filter(s -> !s.isEmpty())
				.toList();
			String name = row.get("name") instanceof String n && !n.isBlank() ? n : parts.isEmpty() ? null
				: parts.getFirst();
			if (name == null) {
				return null;
			}
			// "구로몬 시장, 닛폰바시 2초메, 주오구, 오사카시, ..., 일본" → 이름 뒤의 동네 · 구 · 시까지만
			String address = String.join(", ", parts.stream().filter(p -> !p.equals(name)).limit(3).toList());
			PlaceCategory category = PlaceCategory.fromOsm(String.valueOf(row.get("category")),
				String.valueOf(row.get("type")));
			return new PlaceResponse(name, address, lat, lng, category, PlaceResponse.OSM);
		} catch (NumberFormatException e) {
			return null;
		}
	}

	private static RestClient client(String baseUrl, String userAgent) {
		// 공용 경로 서버가 HTTP/2 응답을 끝까지 보내지 않을 때가 있어 HTTP/1.1로 묻는다
		HttpClient httpClient = HttpClient.newBuilder()
			.version(HttpClient.Version.HTTP_1_1)
			.connectTimeout(CONNECT_TIMEOUT)
			.followRedirects(HttpClient.Redirect.NORMAL)
			.build();
		JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
		factory.setReadTimeout(READ_TIMEOUT);
		// 경로 서버가 보내는 deflate 압축을 JDK가 풀지 못한다 (ZipException). 압축 없이 받는다 (응답이 작다)
		factory.enableCompression(false);
		return RestClient.builder()
			.baseUrl(baseUrl)
			.requestFactory(factory)
			.defaultHeader("User-Agent", userAgent)
			.build();
	}

	// OSRM table 결과. 닿을 수 없는 칸은 null
	public record Matrix(Double[][] durationsSec, Double[][] distancesM) implements Serializable {

		@SuppressWarnings("unchecked")
		static Matrix parse(Map<String, Object> body) {
			if (body == null || !"Ok".equals(body.get("code"))
				|| !(body.get("durations") instanceof List<?> durations)
				|| !(body.get("distances") instanceof List<?> distances)) {
				return null;
			}
			return new Matrix(toArray((List<List<Object>>)durations), toArray((List<List<Object>>)distances));
		}

		private static Double[][] toArray(List<List<Object>> rows) {
			Double[][] out = new Double[rows.size()][];
			for (int i = 0; i < rows.size(); i++) {
				List<Object> row = rows.get(i);
				out[i] = new Double[row.size()];
				for (int j = 0; j < row.size(); j++) {
					out[i][j] = row.get(j) instanceof Number n ? n.doubleValue() : null;
				}
			}
			return out;
		}
	}
}
