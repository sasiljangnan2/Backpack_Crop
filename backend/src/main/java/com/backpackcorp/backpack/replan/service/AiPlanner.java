package com.backpackcorp.backpack.replan.service;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.PlaceResponse;
import com.backpackcorp.backpack.place.service.PlaceService;
import com.backpackcorp.backpack.replan.domain.PlanKey;
import com.backpackcorp.backpack.replan.domain.ReplanCondition;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import lombok.RequiredArgsConstructor;
import tools.jackson.databind.json.JsonMapper;

// Gemini에게 남은 일정의 순서 · 머무는 시간 · 새로 들를 곳을 묻는다.
// 시각은 AI가 정하지 않는다: 돌려받은 순서를 RulePlanner.fit()이 실제 이동 시간으로 다시 맞춘다
@Component
@RequiredArgsConstructor
public class AiPlanner {

	// 안마다 새 장소는 2곳까지
	static final int MAX_NEW_PLACES = 2;

	private static final String INSTRUCTION = """
		너는 여행 중인 사람의 남은 일정을 다시 짜 주는 도우미야. 반드시 JSON 하나만 답해.
		규칙:
		1. anchor(고정 일정)는 바꾸지 않는다. 모든 일정이 끝난 뒤 anchor 장소로 이동해 windowEnd 전에 도착해야 한다.
		2. 일정은 windowStart 이후에 시작한다. 시각은 쓰지 말고 순서와 머무는 시간(stayMin, 분)만 정한다.
		3. 기존 일정은 scheduleId로 가리킨다. 시간이 모자라면 빼도 된다.
		4. 조건(conditions)에 맞는 곳이 기존 일정에 없으면, 현재 장소에서 걸어서 20분 안의 실제로 있는 유명한 장소를
		   scheduleId 없이 넣는다 (안마다 최대 2곳). placeName은 지도에서 찾을 수 있는 현지 이름, title은 한국어로 짧게.
		5. plans는 정확히 3개: CONDITION(조건 일치 우선), MIN_TRAVEL(이동 최소), SLACK(시간 여유 우선, anchor 앞에 30분 이상 여유).
		6. reason은 한국어 1~2문장, "~해요" 말투로 조건과 고정 일정을 어떻게 지켰는지 쓴다. anchor는 "고정 일정" 또는 그 일정 이름으로
		   부르고, anchor · window · target 같은 영어 키 이름은 쓰지 않는다.
		형식: {"plans":[{"key":"CONDITION","reason":"...","items":[{"scheduleId":"...","title":"...","placeName":"...",
		"category":"FOOD","stayMin":50}]}]}
		category는 FOOD, CAFE, SHOPPING, SIGHT, PARK, LODGING, TRANSPORT, ETC 중 하나.
		""";

	private final GeminiClient gemini;
	private final PlaceService placeService;
	private final JsonMapper jsonMapper;

	public boolean available() {
		return gemini.enabled();
	}

	public record Context(
		String destination,
		String now,
		String windowStart,
		String windowEnd,
		String currentPlace,
		LatLng origin,
		Stop anchor,
		List<Stop> targets,
		Set<ReplanCondition> conditions
	) {
	}

	public record Draft(PlanKey key, List<Stop> stops, String reason) {
	}

	// 실패하면 예외. 부르는 쪽이 규칙 기반 추천으로 대신한다
	public List<Draft> suggest(Context context) {
		String answer = gemini.generateJson(INSTRUCTION, prompt(context), schema());
		AiResult result = jsonMapper.readValue(answer, AiResult.class);
		if (result == null || result.plans() == null) {
			throw new IllegalStateException("AI 추천안이 비었어요");
		}
		List<Draft> drafts = new ArrayList<>();
		Set<PlanKey> seen = new HashSet<>();
		for (AiPlan plan : result.plans()) {
			PlanKey key = parseKey(plan.key());
			if (key == null || !seen.add(key) || plan.items() == null) {
				continue;
			}
			drafts.add(new Draft(key, toStops(plan.items(), context), trim(plan.reason())));
		}
		return drafts;
	}

	private List<Stop> toStops(List<AiItem> items, Context context) {
		Map<UUID, Stop> targets = new LinkedHashMap<>();
		context.targets().forEach(s -> targets.put(s.id(), s));
		LatLng near = context.origin() != null ? context.origin()
			: context.anchor() != null ? context.anchor().place() : null;
		List<Stop> stops = new ArrayList<>();
		Set<UUID> used = new HashSet<>();
		int added = 0;
		for (AiItem item : items) {
			boolean refersToSchedule = item.scheduleId() != null && !item.scheduleId().isBlank();
			UUID id = parseId(item.scheduleId());
			if (refersToSchedule) {
				// 없는 일정 번호는 버린다 (새 장소로 바꾸지 않는다)
				Stop target = id == null ? null : targets.get(id);
				if (target != null && used.add(id)) {
					stops.add(target.withStay(clamp(item.stayMin(), 15, 240, target.stayMin())));
				}
				continue;
			}
			if (added >= MAX_NEW_PLACES || item.title() == null || item.title().isBlank()) {
				continue;
			}
			String name = item.placeName() != null && !item.placeName().isBlank() ? item.placeName() : item.title();
			// 좌표는 AI 값을 믿지 않고 지도에서 다시 찾는다. 못 찾으면 좌표 없이 둔다
			PlaceResponse found = near == null ? null : placeService.findNear(name, near);
			LatLng place = found == null ? null : new LatLng(found.lat(), found.lng());
			PlaceCategory category = found != null && found.category() != PlaceCategory.ETC
				? found.category() : parseCategory(item.category());
			stops.add(new Stop(null, limit(item.title(), 100), limit(found != null ? found.name() : name, 100), place,
				category, clamp(item.stayMin(), 20, 120, 40), false));
			added++;
		}
		return stops;
	}

	private String prompt(Context c) {
		Map<String, Object> data = new LinkedHashMap<>();
		data.put("destination", c.destination());
		data.put("now", c.now());
		data.put("windowStart", c.windowStart());
		data.put("windowEnd", c.windowEnd());
		data.put("currentPlace", c.currentPlace());
		if (c.origin() != null) {
			data.put("currentLatLng", List.of(c.origin().lat(), c.origin().lng()));
		}
		if (c.anchor() != null) {
			data.put("anchor", stop(c.anchor()));
		}
		data.put("targets", c.targets().stream().map(AiPlanner::stop).toList());
		data.put("conditions", c.conditions().stream().map(ReplanCondition::label).toList());
		return jsonMapper.writeValueAsString(data);
	}

	private static Map<String, Object> stop(Stop s) {
		Map<String, Object> m = new LinkedHashMap<>();
		if (s.id() != null) {
			m.put("scheduleId", s.id().toString());
		}
		m.put("title", s.title());
		m.put("place", s.placeText());
		m.put("category", s.category() == null ? "ETC" : s.category().name());
		m.put("stayMin", s.stayMin());
		if (s.place() != null) {
			m.put("latLng", List.of(s.place().lat(), s.place().lng()));
		}
		return m;
	}

	private static Map<String, Object> schema() {
		Map<String, Object> item = Map.of(
			"type", "OBJECT",
			"properties", Map.of(
				"scheduleId", Map.of("type", "STRING", "nullable", true),
				"title", Map.of("type", "STRING"),
				"placeName", Map.of("type", "STRING", "nullable", true),
				"category", Map.of("type", "STRING", "enum",
					List.of("FOOD", "CAFE", "SHOPPING", "SIGHT", "PARK", "LODGING", "TRANSPORT", "ETC")),
				"stayMin", Map.of("type", "INTEGER")),
			"required", List.of("title", "stayMin"));
		Map<String, Object> plan = Map.of(
			"type", "OBJECT",
			"properties", Map.of(
				"key", Map.of("type", "STRING", "enum", List.of("CONDITION", "MIN_TRAVEL", "SLACK")),
				"reason", Map.of("type", "STRING"),
				"items", Map.of("type", "ARRAY", "items", item)),
			"required", List.of("key", "reason", "items"));
		return Map.of(
			"type", "OBJECT",
			"properties", Map.of("plans", Map.of("type", "ARRAY", "items", plan)),
			"required", List.of("plans"));
	}

	private static PlanKey parseKey(String key) {
		try {
			return key == null ? null : PlanKey.valueOf(key.trim());
		} catch (IllegalArgumentException e) {
			return null;
		}
	}

	private static UUID parseId(String id) {
		try {
			return id == null || id.isBlank() ? null : UUID.fromString(id.trim());
		} catch (IllegalArgumentException e) {
			return null;
		}
	}

	private static PlaceCategory parseCategory(String category) {
		try {
			return category == null ? PlaceCategory.ETC : PlaceCategory.valueOf(category.trim());
		} catch (IllegalArgumentException e) {
			return PlaceCategory.ETC;
		}
	}

	private static int clamp(Integer value, int min, int max, int fallback) {
		return value == null ? fallback : Math.max(min, Math.min(max, value));
	}

	private static String trim(String reason) {
		return reason == null || reason.isBlank() ? null : limit(reason.trim(), 200);
	}

	private static String limit(String text, int max) {
		return text.length() <= max ? text : text.substring(0, max);
	}

	@JsonIgnoreProperties(ignoreUnknown = true)
	record AiResult(List<AiPlan> plans) {
	}

	@JsonIgnoreProperties(ignoreUnknown = true)
	record AiPlan(String key, String reason, List<AiItem> items) {
	}

	@JsonIgnoreProperties(ignoreUnknown = true)
	record AiItem(String scheduleId, String title, String placeName, String category, Integer stayMin) {
	}
}
