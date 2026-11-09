package com.backpackcorp.backpack.replan.service;

import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.place.dto.TravelLeg;
import com.backpackcorp.backpack.replan.domain.PlanKey;
import com.backpackcorp.backpack.replan.domain.ReplanCondition;
import com.backpackcorp.backpack.replan.dto.ReplanResponse;

// 규칙 기반 일정 재구성. AI 키가 없거나 AI가 실패해도 추천 3안을 만든다 (NFR-02).
// AI 추천안도 여기의 fit()으로 실제 이동 시간에 맞춰 시각을 다시 계산한다 (고정 일정 · 겹침 규칙을 항상 지킨다).
//
// 시각은 자정부터의 분으로 계산하고, 도착 시각은 5분 단위로 올린다
public final class RulePlanner {

	static final int MIN_STAY = 30;
	// "조건 일치 우선" 안은 머무는 시간을 원래의 60%까지 줄여 일정을 살린다
	static final double SHRINK_TO = 0.6;
	// "시간 여유 우선" 안이 고정 일정 앞에 남기는 시간
	static final int SLACK_TARGET = 30;
	// 좌표가 없어 이동 시간을 모를 때 쓰는 값
	static final TravelLeg UNKNOWN_LEG = new TravelLeg(TravelLeg.TravelMode.WALK, 10, 0, 10, 15, null, true);
	static final TravelLeg NO_MOVE = TravelLeg.of(0, 0, 0, false);
	private static final int DAY_END = 23 * 60 + 59;

	private RulePlanner() {
	}

	// 좌표 사이 이동 시간 (ReplanService가 한 번에 받아 둔 표에서 찾는다)
	public interface Travel {
		TravelLeg between(LatLng from, LatLng to);
	}

	// windowEnd: 고정 일정이 있으면 그 시작 시각, 없으면 그날 끝
	public record Input(
		LocalTime windowStart,
		LocalTime windowEnd,
		LatLng origin,
		List<Stop> targets,
		Stop anchor,
		Set<ReplanCondition> conditions
	) {
	}

	public static List<ReplanResponse.Plan> plans(Input in, Travel travel) {
		return List.of(conditionFirst(in, travel), minTravel(in, travel), slackFirst(in, travel));
	}

	// 조건 일치 우선: 조건에 맞는 일정을 남기고, 시간이 모자라면 조건에 덜 맞는 일정부터 뺀다.
	// "휴식 필요"인데 쉴 곳이 없으면 앞 일정 근처에서 30분 쉬어 가는 일정을 넣는다
	static ReplanResponse.Plan conditionFirst(Input in, Travel travel) {
		List<Stop> candidates = new ArrayList<>(in.targets());
		if (in.conditions().contains(ReplanCondition.WALK_15)) {
			dropLongWalks(candidates, in, travel);
		}
		if (in.conditions().contains(ReplanCondition.REST)
			&& candidates.stream().noneMatch(s -> ReplanCondition.REST.matches(s.category()))) {
			Stop rest = new Stop(null, "잠깐 쉬어 가기", "근처 카페", null, PlaceCategory.CAFE, MIN_STAY, true);
			candidates.add(Math.min(1, candidates.size()), rest);
		}
		while (true) {
			ReplanResponse.Plan plan = fit(PlanKey.CONDITION, candidates, in, travel, true, null);
			Set<UUID> placed = idsOf(plan);
			List<Stop> missing = candidates.stream().filter(s -> !s.isNew() && !placed.contains(s.id())).toList();
			if (missing.isEmpty() || candidates.size() <= 1) {
				return withDropped(plan, in);
			}
			// 조건 점수가 가장 낮은 일정(같으면 늦은 것)을 빼고 다시 맞춘다
			Stop weakest = candidates.stream()
				.filter(s -> !s.isNew())
				.min(Comparator.comparingInt((Stop s) -> score(s, in.conditions()))
					.thenComparing(s -> -candidates.indexOf(s)))
				.orElseThrow();
			candidates.remove(weakest);
		}
	}

	// 이동 최소: 지금 있는 곳에서 가장 가까운 곳부터 차례로 들른다
	static ReplanResponse.Plan minTravel(Input in, Travel travel) {
		List<Stop> remaining = new ArrayList<>(in.targets());
		List<Stop> ordered = new ArrayList<>();
		LatLng at = in.origin();
		while (!remaining.isEmpty()) {
			LatLng from = at;
			Stop next = remaining.stream()
				.min(Comparator.comparingInt(s -> s.place() == null || from == null
					? Integer.MAX_VALUE
					: travel.between(from, s.place()).minutes()))
				.orElseThrow();
			ordered.add(next);
			remaining.remove(next);
			if (next.place() != null) {
				at = next.place();
			}
		}
		return withDropped(fit(PlanKey.MIN_TRAVEL, ordered, in, travel, false, null), in);
	}

	// 시간 여유 우선: 원래 순서대로, 고정 일정 앞에 30분 이상 남도록 담는다
	static ReplanResponse.Plan slackFirst(Input in, Travel travel) {
		return withDropped(fit(PlanKey.SLACK, in.targets(), in, travel, false, null), in);
	}

	// 순서대로 시각을 정한다. 고정 일정(anchor)까지 제때 갈 수 없는 일정은 건너뛴다.
	// reason이 null이면 결과를 보고 설명을 만든다
	public static ReplanResponse.Plan fit(PlanKey key, List<Stop> ordered, Input in, Travel travel,
		boolean allowShrink, String reason) {
		int limit = minutes(in.windowEnd()) - (key == PlanKey.SLACK && in.anchor() != null ? SLACK_TARGET : 0);
		int t = roundUp(minutes(in.windowStart()));
		LatLng prev = in.origin();
		List<ReplanResponse.Item> items = new ArrayList<>();
		List<TravelLeg> legs = new ArrayList<>();
		for (Stop stop : ordered) {
			TravelLeg leg = stop.nearby() ? NO_MOVE : leg(travel, prev, stop.place());
			int arrive = roundUp(t + leg.minutes());
			LatLng here = stop.place() != null ? stop.place() : prev;
			int toAnchor = in.anchor() == null ? 0 : leg(travel, here, in.anchor().place()).minutes();
			int stay = stop.stayMin();
			if (arrive + stay + toAnchor > limit) {
				int room = limit - toAnchor - arrive;
				int shortest = Math.max(MIN_STAY, (int)Math.ceil(stop.stayMin() * SHRINK_TO));
				if (!allowShrink || room < Math.min(shortest, stop.stayMin())) {
					continue;
				}
				stay = room;
			}
			if (arrive + stay > DAY_END) {
				continue;
			}
			items.add(new ReplanResponse.Item(stop.id(), stop.title(), stop.placeText(),
				here == null ? null : here.lat(), here == null ? null : here.lng(), stop.category(), time(arrive),
				time(arrive + stay), stay, leg, stop.isNew()));
			legs.add(leg);
			t = arrive + stay;
			prev = here;
		}
		TravelLeg last = in.anchor() == null ? null : leg(travel, prev, in.anchor().place());
		if (last != null) {
			legs.add(last);
		}
		Integer slack = in.anchor() == null ? null : minutes(in.windowEnd()) - t - last.minutes();
		int travelMin = legs.stream().mapToInt(TravelLeg::minutes).sum();
		int rate = conditionRate(items, legs, in.conditions());
		LocalTime start = items.isEmpty() ? in.windowStart() : items.getFirst().startTime();
		LocalTime end = items.isEmpty() ? in.windowStart() : items.getLast().endTime();
		ReplanResponse.Plan plan = new ReplanResponse.Plan(key, key.label(), reason, start, end, travelMin, slack,
			rate, items, last, List.of());
		return reason != null ? plan : withReason(plan, legs, in);
	}

	static ReplanResponse.Plan withDropped(ReplanResponse.Plan plan, Input in) {
		Set<UUID> placed = idsOf(plan);
		List<ReplanResponse.Dropped> dropped = in.targets().stream()
			.filter(s -> !placed.contains(s.id()))
			.map(s -> new ReplanResponse.Dropped(s.id(), s.title()))
			.toList();
		ReplanResponse.Plan withList = new ReplanResponse.Plan(plan.key(), plan.label(), plan.reason(),
			plan.startTime(), plan.endTime(), plan.travelMin(), plan.slackMin(), plan.conditionRate(), plan.items(),
			plan.travelToAnchor(), dropped);
		// 빠진 일정이 있으면 설명에 덧붙인다 (AI가 일부러 뺀 경우도 있으므로 까닭은 붙이지 않는다)
		if (dropped.isEmpty() || plan.reason() == null || plan.reason().contains("빠지는 일정")) {
			return withList;
		}
		String names = dropped.stream().map(d -> "'" + d.title() + "'").collect(Collectors.joining(", "));
		return new ReplanResponse.Plan(withList.key(), withList.label(),
			withList.reason() + " 빠지는 일정: " + names + ".", withList.startTime(),
			withList.endTime(), withList.travelMin(), withList.slackMin(), withList.conditionRate(), withList.items(),
			withList.travelToAnchor(), dropped);
	}

	static int conditionRate(List<ReplanResponse.Item> items, List<TravelLeg> legs, Set<ReplanCondition> conditions) {
		if (conditions.isEmpty()) {
			return 100;
		}
		long ok = conditions.stream().filter(c -> c.satisfiedBy(items, legs)).count();
		return (int)Math.round(100.0 * ok / conditions.size());
	}

	private static ReplanResponse.Plan withReason(ReplanResponse.Plan plan, List<TravelLeg> legs, Input in) {
		List<String> parts = new ArrayList<>();
		if (plan.items().isEmpty()) {
			parts.add("남은 시간이 모자라 새로 넣을 수 있는 일정이 없어요.");
		} else {
			Set<ReplanCondition> met = new LinkedHashSet<>();
			Set<ReplanCondition> missed = new LinkedHashSet<>();
			for (ReplanCondition c : in.conditions()) {
				(c.satisfiedBy(plan.items(), legs) ? met : missed).add(c);
			}
			String head = switch (plan.key()) {
				case CONDITION -> "";
				case MIN_TRAVEL -> "가까운 곳부터 들러 이동을 " + plan.travelMin() + "분으로 줄였어요.";
				case SLACK -> "원래 순서를 지키면서 시간에 여유를 두었어요.";
			};
			if (!head.isEmpty()) {
				parts.add(head);
			}
			if (!met.isEmpty()) {
				parts.add(labels(met) + " 조건을 맞췄어요.");
			}
			if (!missed.isEmpty()) {
				parts.add(labels(missed) + " 조건은 지키지 못했어요.");
			}
		}
		if (in.anchor() != null && plan.slackMin() != null) {
			parts.add(plan.slackMin() == 0
				? String.format("%s '%s'에 딱 맞춰 도착해요.", in.windowEnd(), in.anchor().title())
				: String.format("%s '%s'까지 %d분 여유가 있어요.", in.windowEnd(), in.anchor().title(),
					plan.slackMin()));
		}
		return new ReplanResponse.Plan(plan.key(), plan.label(), String.join(" ", parts), plan.startTime(),
			plan.endTime(), plan.travelMin(), plan.slackMin(), plan.conditionRate(), plan.items(),
			plan.travelToAnchor(), plan.dropped());
	}

	private static String labels(Set<ReplanCondition> conditions) {
		return conditions.stream().map(ReplanCondition::label).collect(Collectors.joining(" · "));
	}

	// 도보 조건: 앞 일정에서 걸어서 15분이 넘는 일정 중 다른 조건에도 맞지 않는 것을 뺀다
	private static void dropLongWalks(List<Stop> candidates, Input in, Travel travel) {
		LatLng prev = in.origin();
		for (Stop stop : new ArrayList<>(candidates)) {
			TravelLeg leg = leg(travel, prev, stop.place());
			if (candidates.size() > 1 && leg.walkMin() > ReplanCondition.WALK_LIMIT_MIN
				&& score(stop, in.conditions()) == 0) {
				candidates.remove(stop);
				continue;
			}
			if (stop.place() != null) {
				prev = stop.place();
			}
		}
	}

	private static int score(Stop stop, Set<ReplanCondition> conditions) {
		return (int)conditions.stream().filter(c -> c.matches(stop.category())).count();
	}

	private static Set<UUID> idsOf(ReplanResponse.Plan plan) {
		Set<UUID> ids = new HashSet<>();
		plan.items().forEach(item -> {
			if (item.scheduleId() != null) {
				ids.add(item.scheduleId());
			}
		});
		return ids;
	}

	private static TravelLeg leg(Travel travel, LatLng from, LatLng to) {
		if (from == null || to == null) {
			return from == null && to == null ? NO_MOVE : UNKNOWN_LEG;
		}
		return from.equals(to) ? NO_MOVE : travel.between(from, to);
	}

	static int minutes(LocalTime time) {
		return time.getHour() * 60 + time.getMinute();
	}

	static LocalTime time(int minutes) {
		int clamped = Math.max(0, Math.min(DAY_END, minutes));
		return LocalTime.of(clamped / 60, clamped % 60);
	}

	private static int roundUp(int minutes) {
		return (minutes + 4) / 5 * 5;
	}
}
