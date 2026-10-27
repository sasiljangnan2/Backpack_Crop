package com.backpackcorp.backpack.replan.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.PlaceResponse;
import com.backpackcorp.backpack.place.service.PlaceService;
import com.backpackcorp.backpack.replan.domain.PlanKey;
import com.backpackcorp.backpack.replan.domain.ReplanCondition;

import tools.jackson.databind.json.JsonMapper;

class AiPlannerTest {

	private static final LatLng KUROMON = new LatLng(34.6655, 135.5066);

	private final GeminiClient gemini = mock(GeminiClient.class);
	private final PlaceService places = mock(PlaceService.class);
	private final AiPlanner planner = new AiPlanner(gemini, places, JsonMapper.builder().build());

	private final Stop shopping = new Stop(UUID.randomUUID(), "신사이바시 쇼핑", "신사이바시",
		new LatLng(34.6745, 135.5013), PlaceCategory.SHOPPING, 60, false);

	@Test
	void AI가_고른_기존_일정과_새_장소를_좌표를_확인해_돌려준다() {
		when(places.findNear(eq("大丸心斎橋店"), any())).thenReturn(
			new PlaceResponse("다이마루 신사이바시점", "신사이바시스지", 34.6731, 135.5012, PlaceCategory.SHOPPING,
				PlaceResponse.GOOGLE));
		when(gemini.generateJson(anyString(), anyString(), any())).thenReturn("""
			{"plans":[
			  {"key":"CONDITION","reason":"먹거리 조건에 맞춰 백화점 지하 식품관을 넣었어요.","items":[
			    {"title":"다이마루 지하 식품관","placeName":"大丸心斎橋店","category":"FOOD","stayMin":50},
			    {"scheduleId":"%s","title":"신사이바시 쇼핑","stayMin":500},
			    {"scheduleId":"%s","title":"같은 일정 두 번","stayMin":30},
			    {"scheduleId":"not-a-uuid","title":"모르는 일정","stayMin":30}]},
			  {"key":"UNKNOWN","reason":"","items":[]},
			  {"key":"SLACK","reason":"","items":[{"scheduleId":"%s","title":"신사이바시 쇼핑","stayMin":40}]}
			]}
			""".formatted(shopping.id(), shopping.id(), shopping.id()));

		List<AiPlanner.Draft> drafts = planner.suggest(context());

		assertThat(drafts).extracting(AiPlanner.Draft::key).containsExactly(PlanKey.CONDITION, PlanKey.SLACK);
		List<Stop> stops = drafts.getFirst().stops();
		assertThat(stops).hasSize(2);
		// 새 장소는 지도에서 찾은 이름 · 좌표 · 분류를 쓴다
		assertThat(stops.getFirst().isNew()).isTrue();
		assertThat(stops.getFirst().placeText()).isEqualTo("다이마루 신사이바시점");
		assertThat(stops.getFirst().place()).isEqualTo(new LatLng(34.6731, 135.5012));
		// 기존 일정의 머무는 시간은 4시간을 넘지 않는다
		assertThat(stops.get(1).id()).isEqualTo(shopping.id());
		assertThat(stops.get(1).stayMin()).isEqualTo(240);
		assertThat(drafts.getFirst().reason()).contains("식품관");
	}

	@Test
	void 지도에서_못_찾은_새_장소는_좌표_없이_둔다() {
		when(gemini.generateJson(anyString(), anyString(), any())).thenReturn("""
			{"plans":[{"key":"MIN_TRAVEL","reason":"r","items":[{"title":"어딘가 카페","category":"CAFE","stayMin":30}]}]}
			""");

		Stop stop = planner.suggest(context()).getFirst().stops().getFirst();

		assertThat(stop.place()).isNull();
		assertThat(stop.category()).isEqualTo(PlaceCategory.CAFE);
	}

	@Test
	void JSON이_아니면_예외를_던진다() {
		when(gemini.generateJson(anyString(), anyString(), any())).thenReturn("추천할 수 없어요");

		assertThatThrownBy(() -> planner.suggest(context())).isInstanceOf(RuntimeException.class);
	}

	@Test
	void 응답의_생각_과정은_빼고_글만_모은다() {
		Map<String, Object> response = Map.of("candidates", List.of(Map.of("content", Map.of("parts", List.of(
			Map.of("text", "생각 중", "thought", true),
			Map.of("text", "{\"plans\":"),
			Map.of("text", "[]}"))))));

		assertThat(GeminiClient.textOf(response)).isEqualTo("{\"plans\":[]}");
		assertThatThrownBy(() -> GeminiClient.textOf(Map.of("candidates", List.of())))
			.isInstanceOf(IllegalStateException.class);
	}

	private AiPlanner.Context context() {
		return new AiPlanner.Context("일본 오사카", "14:50", "14:50", "17:30", "구로몬 시장", KUROMON, null,
			List.of(shopping), EnumSet.of(ReplanCondition.FOOD));
	}
}
