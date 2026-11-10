package com.backpackcorp.backpack.replan.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalTime;
import java.util.EnumSet;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.TravelLeg;
import com.backpackcorp.backpack.replan.domain.PlanKey;
import com.backpackcorp.backpack.replan.domain.ReplanCondition;
import com.backpackcorp.backpack.replan.dto.ReplanResponse;

// AI 안을 규칙 기반 안과 합칠 때, 같은 곳을 같은 순서로 들르는 안이 두 장 나오지 않게 한다
class ReplanMergeTest {

	private static final LatLng KUROMON = new LatLng(34.6655, 135.5066);
	private static final LatLng DOTONBORI = new LatLng(34.6687, 135.5013);
	private static final LatLng SHINSAIBASHI = new LatLng(34.6745, 135.5013);
	private static final LatLng NAKANOSHIMA = new LatLng(34.6927, 135.5060);
	private static final LatLng UMEDA = new LatLng(34.7053, 135.4896);

	// 직선거리 × 1.3 ÷ 분속 75m
	private static final RulePlanner.Travel WALK = (from, to) -> {
		int distance = (int)Math.round(from.distanceTo(to) * 1.3);
		int walk = (int)Math.ceil(distance / 75.0);
		return TravelLeg.of(distance, walk, walk / 3 + 5, false);
	};

	private final Stop park = new Stop(UUID.randomUUID(), "나카노시마 공원", "나카노시마", NAKANOSHIMA, PlaceCategory.PARK,
		30, false);
	private final Stop shopping = new Stop(UUID.randomUUID(), "신사이바시 쇼핑", "신사이바시", SHINSAIBASHI,
		PlaceCategory.SHOPPING, 60, false);
	private final Stop food = new Stop(UUID.randomUUID(), "도톤보리 먹거리", "도톤보리", DOTONBORI, PlaceCategory.FOOD, 40,
		false);
	private final Stop anchor = new Stop(UUID.randomUUID(), "우메다 스카이빌딩", "우메다", UMEDA, PlaceCategory.SIGHT, 90,
		false);

	// 규칙 기반 안: 조건 일치 · 여유 우선은 원래 순서(공원 → 쇼핑 → 먹거리), 이동 최소는 가까운 순(먹거리 → 쇼핑 → 공원)
	private final RulePlanner.Input input = new RulePlanner.Input(LocalTime.of(11, 0), LocalTime.of(17, 30), KUROMON,
		List.of(park, shopping, food), anchor, EnumSet.noneOf(ReplanCondition.class));
	private final List<ReplanResponse.Plan> rulePlans = RulePlanner.plans(input, WALK);

	@Test
	void AI_안이_앞의_안과_같으면_같은_기준의_규칙_기반_안으로_바꾼다() {
		List<AiPlanner.Draft> drafts = List.of(
			draft(PlanKey.CONDITION, "AI 조건 안", shopping, park, food),
			draft(PlanKey.MIN_TRAVEL, "AI 이동 안", shopping, park, food),
			draft(PlanKey.SLACK, "AI 여유 안", food, park, shopping));

		List<ReplanResponse.Plan> merged = ReplanService.merge(drafts, rulePlans, input, WALK);

		assertThat(merged).extracting(ReplanResponse.Plan::key)
			.containsExactly(PlanKey.CONDITION, PlanKey.MIN_TRAVEL, PlanKey.SLACK);
		assertThat(route(merged.get(0))).containsExactly(shopping.id(), park.id(), food.id());
		assertThat(merged.get(0).reason()).isEqualTo("AI 조건 안");
		// 1안과 겹친 AI 이동 안 대신 규칙 기반 이동 최소 안
		assertThat(merged.get(1)).isEqualTo(rulePlans.get(1));
		assertThat(route(merged.get(1))).containsExactly(food.id(), shopping.id(), park.id());
		assertThat(route(merged.get(2))).containsExactly(food.id(), park.id(), shopping.id());
		assertThat(merged.get(2).reason()).isEqualTo("AI 여유 안");
		assertThat(merged).extracting(ReplanMergeTest::route).doesNotHaveDuplicates();
	}

	@Test
	void 규칙_기반_안도_앞의_안과_같으면_그_안은_빼고_보낸다() {
		// AI 조건 안이 규칙 기반 이동 최소 안과 같은 순서라 바꿔도 겹친다
		List<AiPlanner.Draft> drafts = List.of(
			draft(PlanKey.CONDITION, "AI 조건 안", food, shopping, park),
			draft(PlanKey.MIN_TRAVEL, "AI 이동 안", food, shopping, park));

		List<ReplanResponse.Plan> merged = ReplanService.merge(drafts, rulePlans, input, WALK);

		assertThat(merged).extracting(ReplanResponse.Plan::key).containsExactly(PlanKey.CONDITION, PlanKey.SLACK);
		assertThat(merged.get(0).reason()).isEqualTo("AI 조건 안");
		// AI가 답하지 않은 여유 안은 규칙 기반 안
		assertThat(merged.get(1)).isEqualTo(rulePlans.get(2));
	}

	@Test
	void AI_안이_없어_들어간_규칙_기반_안도_앞의_안과_같으면_뺀다() {
		// AI 조건 안이 규칙 기반 여유 안(원래 순서)과 같다. AI는 여유 안을 답하지 않았다
		List<AiPlanner.Draft> drafts = List.of(draft(PlanKey.CONDITION, "AI 조건 안", park, shopping, food));

		List<ReplanResponse.Plan> merged = ReplanService.merge(drafts, rulePlans, input, WALK);

		assertThat(merged).extracting(ReplanResponse.Plan::key).containsExactly(PlanKey.CONDITION, PlanKey.MIN_TRAVEL);
		assertThat(merged).extracting(ReplanMergeTest::route).doesNotHaveDuplicates();
	}

	@Test
	void 겹치지_않으면_AI_안을_모두_쓴다() {
		List<AiPlanner.Draft> drafts = List.of(
			draft(PlanKey.CONDITION, "AI 조건 안", shopping, park, food),
			draft(PlanKey.MIN_TRAVEL, "AI 이동 안", food, shopping, park),
			draft(PlanKey.SLACK, "AI 여유 안", park, shopping, food));

		List<ReplanResponse.Plan> merged = ReplanService.merge(drafts, rulePlans, input, WALK);

		assertThat(merged).extracting(ReplanResponse.Plan::reason)
			.containsExactly("AI 조건 안", "AI 이동 안", "AI 여유 안");
	}

	private static AiPlanner.Draft draft(PlanKey key, String reason, Stop... stops) {
		return new AiPlanner.Draft(key, List.of(stops), reason);
	}

	private static List<UUID> route(ReplanResponse.Plan plan) {
		return plan.items().stream().map(ReplanResponse.Item::scheduleId).toList();
	}
}
