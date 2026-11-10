package com.backpackcorp.backpack.replan.service;

import java.time.Duration;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import com.backpackcorp.backpack.replan.dto.ReplanResponse;

// BP-AI-003 추천안 고르기: 서로 같은 안은 하나로 합치고(이름을 이어 붙인다), 지금 일정과 같은 안과
// (다른 안이 있으면) 일정을 하나도 넣지 못하는 안은 뺀다. 그래서 보여 주는 안은 0~3개다. 같은 장소를 같은 순서로 돌고 시각이 SAME_WITHIN_MIN분 안쪽으로만 다르면 같은 안으로 본다
final class PlanFilter {

	static final int SAME_WITHIN_MIN = 10;

	private PlanFilter() {
	}

	// 다시 짜기 전의 일정 (시작 시각순)
	record Current(UUID scheduleId, LocalTime startTime, LocalTime endTime) {
	}

	static List<ReplanResponse.Plan> distinct(List<ReplanResponse.Plan> plans, List<Current> current) {
		List<ReplanResponse.Plan> kept = new ArrayList<>();
		for (ReplanResponse.Plan plan : plans) {
			if (sameAsCurrent(plan, current)) {
				continue;
			}
			int same = indexOfSame(kept, plan);
			if (same < 0) {
				kept.add(plan);
			} else {
				kept.set(same, withLabel(kept.get(same), kept.get(same).label() + " · " + plan.label()));
			}
		}
		// 일정을 하나도 넣지 못하고 지우기만 하는 안은, 일정을 넣는 다른 안이 있으면 보여 주지 않는다
		if (kept.stream().anyMatch(p -> !p.items().isEmpty())) {
			kept.removeIf(p -> p.items().isEmpty());
		}
		return kept;
	}

	static boolean sameAsCurrent(ReplanResponse.Plan plan, List<Current> current) {
		if (!plan.dropped().isEmpty() || plan.items().size() != current.size()) {
			return false;
		}
		for (int i = 0; i < current.size(); i++) {
			ReplanResponse.Item item = plan.items().get(i);
			Current now = current.get(i);
			if (item.isNew() || !now.scheduleId().equals(item.scheduleId())
				|| apart(item.startTime(), now.startTime()) || apart(item.endTime(), now.endTime())) {
				return false;
			}
		}
		return true;
	}

	static boolean same(ReplanResponse.Plan a, ReplanResponse.Plan b) {
		if (a.items().size() != b.items().size() || !droppedIds(a).equals(droppedIds(b))) {
			return false;
		}
		for (int i = 0; i < a.items().size(); i++) {
			ReplanResponse.Item x = a.items().get(i);
			ReplanResponse.Item y = b.items().get(i);
			if (!samePlace(x, y) || apart(x.startTime(), y.startTime()) || apart(x.endTime(), y.endTime())) {
				return false;
			}
		}
		return true;
	}

	private static int indexOfSame(List<ReplanResponse.Plan> kept, ReplanResponse.Plan plan) {
		for (int i = 0; i < kept.size(); i++) {
			if (same(kept.get(i), plan)) {
				return i;
			}
		}
		return -1;
	}

	// 원래 일정은 id로, 새로 넣는 일정(휴식 · AI가 찾은 장소)은 이름과 장소로 비교한다
	private static boolean samePlace(ReplanResponse.Item x, ReplanResponse.Item y) {
		if (x.scheduleId() != null || y.scheduleId() != null) {
			return Objects.equals(x.scheduleId(), y.scheduleId());
		}
		return Objects.equals(x.title(), y.title()) && Objects.equals(x.placeText(), y.placeText());
	}

	private static Set<UUID> droppedIds(ReplanResponse.Plan plan) {
		return plan.dropped().stream().map(ReplanResponse.Dropped::scheduleId).collect(Collectors.toSet());
	}

	private static boolean apart(LocalTime a, LocalTime b) {
		return Math.abs(Duration.between(a, b).toMinutes()) > SAME_WITHIN_MIN;
	}

	private static ReplanResponse.Plan withLabel(ReplanResponse.Plan p, String label) {
		return new ReplanResponse.Plan(p.key(), label, p.reason(), p.startTime(), p.endTime(), p.travelMin(),
			p.slackMin(), p.conditionRate(), p.items(), p.travelToAnchor(), p.dropped());
	}
}
