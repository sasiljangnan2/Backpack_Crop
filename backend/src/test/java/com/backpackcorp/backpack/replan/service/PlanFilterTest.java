package com.backpackcorp.backpack.replan.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.backpackcorp.backpack.place.dto.TravelLeg;
import com.backpackcorp.backpack.replan.domain.PlanKey;
import com.backpackcorp.backpack.replan.dto.ReplanResponse;

class PlanFilterTest {

	private final UUID shopping = UUID.randomUUID();
	private final UUID park = UUID.randomUUID();
	// 지금 일정: 쇼핑 15:00–16:00 → 공원 16:30–17:00
	private final List<PlanFilter.Current> current = List.of(
		new PlanFilter.Current(shopping, LocalTime.of(15, 0), LocalTime.of(16, 0)),
		new PlanFilter.Current(park, LocalTime.of(16, 30), LocalTime.of(17, 0)));

	@Test
	void 지금_일정과_같은_안은_빼고_서로_같은_안은_이름을_합친다() {
		ReplanResponse.Plan sameAsNow = plan(PlanKey.CONDITION, item(shopping, 15, 5, 16, 5), item(park, 16, 30, 17, 0));
		ReplanResponse.Plan parkFirst = plan(PlanKey.MIN_TRAVEL, item(park, 15, 0, 15, 30), item(shopping, 16, 0, 17, 0));
		ReplanResponse.Plan alsoParkFirst = plan(PlanKey.SLACK, item(park, 15, 5, 15, 35), item(shopping, 16, 0, 17, 0));

		List<ReplanResponse.Plan> kept = PlanFilter.distinct(List.of(sameAsNow, parkFirst, alsoParkFirst), current);

		assertThat(kept).hasSize(1);
		assertThat(kept.getFirst().key()).isEqualTo(PlanKey.MIN_TRAVEL);
		assertThat(kept.getFirst().label()).isEqualTo("이동 최소 · 시간 여유 우선");
	}

	@Test
	void 순서가_같아도_시각이_10분_넘게_다르면_다른_안이다() {
		// 늦어져서 뒤로 미룬 안은 지금 일정과 다르다
		ReplanResponse.Plan later = plan(PlanKey.CONDITION, item(shopping, 15, 40, 16, 40), item(park, 17, 0, 17, 30));
		ReplanResponse.Plan shorter = plan(PlanKey.SLACK, item(shopping, 15, 40, 16, 10), item(park, 16, 30, 17, 0));

		List<ReplanResponse.Plan> kept = PlanFilter.distinct(List.of(later, shorter), current);

		assertThat(kept).extracting(ReplanResponse.Plan::key).containsExactly(PlanKey.CONDITION, PlanKey.SLACK);
	}

	@Test
	void 빠지는_일정이나_새로_넣는_일정이_다르면_다른_안이다() {
		ReplanResponse.Plan dropPark = plan(PlanKey.CONDITION, List.of(item(shopping, 15, 0, 16, 0)),
			List.of(new ReplanResponse.Dropped(park, "공원")));
		ReplanResponse.Plan rest = plan(PlanKey.SLACK, List.of(item(shopping, 15, 0, 16, 0), rest(16, 10, 16, 40)),
			List.of(new ReplanResponse.Dropped(park, "공원")));

		assertThat(PlanFilter.distinct(List.of(dropPark, rest), current)).hasSize(2);
	}

	@Test
	void 일정을_넣는_안이_있으면_지우기만_하는_안은_뺀다() {
		ReplanResponse.Plan later = plan(PlanKey.CONDITION, item(shopping, 15, 40, 16, 40), item(park, 17, 0, 17, 30));
		ReplanResponse.Plan dropAll = plan(PlanKey.SLACK, List.of(), List.of(
			new ReplanResponse.Dropped(shopping, "쇼핑"), new ReplanResponse.Dropped(park, "공원")));

		assertThat(PlanFilter.distinct(List.of(later, dropAll), current))
			.extracting(ReplanResponse.Plan::key).containsExactly(PlanKey.CONDITION);
		// 넣을 수 있는 안이 하나도 없으면 그대로 보여 준다 (시간이 모자라 지워야 하는 경우)
		assertThat(PlanFilter.distinct(List.of(dropAll), current)).hasSize(1);
	}

	@Test
	void 모든_안이_지금_일정과_같으면_보여_줄_안이_없다() {
		ReplanResponse.Plan a = plan(PlanKey.CONDITION, item(shopping, 15, 0, 16, 0), item(park, 16, 30, 17, 0));
		ReplanResponse.Plan b = plan(PlanKey.MIN_TRAVEL, item(shopping, 14, 55, 15, 55), item(park, 16, 25, 16, 55));

		assertThat(PlanFilter.distinct(List.of(a, b), current)).isEmpty();
	}

	private static ReplanResponse.Plan plan(PlanKey key, ReplanResponse.Item... items) {
		return plan(key, List.of(items), List.of());
	}

	private static ReplanResponse.Plan plan(PlanKey key, List<ReplanResponse.Item> items,
		List<ReplanResponse.Dropped> dropped) {
		LocalTime start = items.isEmpty() ? LocalTime.of(15, 0) : items.getFirst().startTime();
		LocalTime end = items.isEmpty() ? start : items.getLast().endTime();
		return new ReplanResponse.Plan(key, key.label(), "이유", start, end, 10, null, 100, items, null, dropped);
	}

	private static ReplanResponse.Item item(UUID id, int sh, int sm, int eh, int em) {
		LocalTime start = LocalTime.of(sh, sm);
		LocalTime end = LocalTime.of(eh, em);
		return new ReplanResponse.Item(id, "일정", null, null, null, null, start, end,
			(int)java.time.Duration.between(start, end).toMinutes(), TravelLeg.of(0, 0, 0, false), false);
	}

	private static ReplanResponse.Item rest(int sh, int sm, int eh, int em) {
		return new ReplanResponse.Item(null, "잠깐 쉬어 가기", null, null, null, null, LocalTime.of(sh, sm),
			LocalTime.of(eh, em), 30, TravelLeg.of(0, 0, 0, false), true);
	}
}
