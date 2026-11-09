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

class RulePlannerTest {

	private static final LatLng KUROMON = new LatLng(34.6655, 135.5066);
	private static final LatLng SHINSAIBASHI = new LatLng(34.6745, 135.5013);
	private static final LatLng NAKANOSHIMA = new LatLng(34.6927, 135.5060);
	private static final LatLng UMEDA = new LatLng(34.7053, 135.4896);

	// 직선거리 × 1.3 ÷ 분속 75m
	private static final RulePlanner.Travel WALK = (from, to) -> {
		int distance = (int)Math.round(from.distanceTo(to) * 1.3);
		int walk = (int)Math.ceil(distance / 75.0);
		return TravelLeg.of(distance, walk, walk / 3 + 5, false);
	};

	private final Stop shopping = new Stop(UUID.randomUUID(), "신사이바시 쇼핑", "신사이바시", SHINSAIBASHI,
		PlaceCategory.SHOPPING, 60, false);
	private final Stop park = new Stop(UUID.randomUUID(), "나카노시마 공원", "나카노시마", NAKANOSHIMA, PlaceCategory.PARK,
		30, false);
	private final Stop anchor = new Stop(UUID.randomUUID(), "우메다 스카이빌딩", "우메다", UMEDA, PlaceCategory.SIGHT, 90,
		false);

	@Test
	void 세_안_모두_고정_일정_전에_끝나고_시각이_겹치지_않는다() {
		RulePlanner.Input in = input(LocalTime.of(14, 50), EnumSet.noneOf(ReplanCondition.class));

		List<ReplanResponse.Plan> plans = RulePlanner.plans(in, WALK);

		assertThat(plans).extracting(ReplanResponse.Plan::key)
			.containsExactly(PlanKey.CONDITION, PlanKey.MIN_TRAVEL, PlanKey.SLACK);
		for (ReplanResponse.Plan plan : plans) {
			assertThat(plan.slackMin()).isNotNegative();
			assertThat(plan.items().getFirst().startTime()).isAfterOrEqualTo(LocalTime.of(14, 50));
			for (int i = 1; i < plan.items().size(); i++) {
				assertThat(plan.items().get(i).startTime()).isAfterOrEqualTo(plan.items().get(i - 1).endTime());
			}
			assertThat(plan.reason()).contains("우메다 스카이빌딩");
		}
		// 여유 우선 안은 고정 일정 앞에 30분 이상 남긴다
		assertThat(plans.get(2).slackMin()).isGreaterThanOrEqualTo(RulePlanner.SLACK_TARGET);
	}

	@Test
	void 휴식이_필요한데_쉴_곳이_없으면_쉬어_가는_일정을_넣는다() {
		Stop food = new Stop(UUID.randomUUID(), "도톤보리", "도톤보리", KUROMON, PlaceCategory.FOOD, 40, false);
		RulePlanner.Input in = new RulePlanner.Input(LocalTime.of(14, 50), LocalTime.of(17, 30), KUROMON,
			List.of(food, shopping), anchor, EnumSet.of(ReplanCondition.REST, ReplanCondition.FOOD));

		ReplanResponse.Plan plan = RulePlanner.conditionFirst(in, WALK);

		assertThat(plan.items()).extracting(ReplanResponse.Item::title).contains("잠깐 쉬어 가기");
		assertThat(plan.items()).filteredOn(ReplanResponse.Item::isNew).singleElement()
			.satisfies(rest -> assertThat(rest.travelBefore().minutes()).isZero());
		assertThat(plan.conditionRate()).isEqualTo(100);
	}

	@Test
	void 시간이_모자라면_조건에_덜_맞는_일정부터_뺀다() {
		// 15:30 출발이면 둘 다 넣을 수 없다. 실내(쇼핑)를 바라므로 공원을 뺀다
		RulePlanner.Input in = input(LocalTime.of(15, 30), EnumSet.of(ReplanCondition.INDOOR));

		ReplanResponse.Plan plan = RulePlanner.conditionFirst(in, WALK);

		assertThat(plan.items()).extracting(ReplanResponse.Item::scheduleId).containsExactly(shopping.id());
		assertThat(plan.dropped()).extracting(ReplanResponse.Dropped::title).containsExactly("나카노시마 공원");
		assertThat(plan.reason()).contains("빠지는 일정: '나카노시마 공원'");
	}

	@Test
	void 이동_최소_안은_가까운_곳부터_들른다() {
		RulePlanner.Input in = new RulePlanner.Input(LocalTime.of(14, 50), LocalTime.of(17, 30), KUROMON,
			List.of(park, shopping), anchor, EnumSet.noneOf(ReplanCondition.class));

		ReplanResponse.Plan plan = RulePlanner.minTravel(in, WALK);

		assertThat(plan.items()).extracting(ReplanResponse.Item::scheduleId).containsExactly(shopping.id(), park.id());
	}

	@Test
	void 남은_시간이_없으면_빈_안과_빠진_일정을_돌려준다() {
		RulePlanner.Input in = input(LocalTime.of(17, 20), EnumSet.noneOf(ReplanCondition.class));

		ReplanResponse.Plan plan = RulePlanner.slackFirst(in, WALK);

		assertThat(plan.items()).isEmpty();
		assertThat(plan.dropped()).hasSize(2);
		assertThat(plan.reason()).contains("남은 시간이 모자라");
	}

	private RulePlanner.Input input(LocalTime start, EnumSet<ReplanCondition> conditions) {
		return new RulePlanner.Input(start, LocalTime.of(17, 30), KUROMON, List.of(shopping, park), anchor,
			conditions);
	}
}
