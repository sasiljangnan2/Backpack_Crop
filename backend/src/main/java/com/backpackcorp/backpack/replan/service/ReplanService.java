package com.backpackcorp.backpack.replan.service;

import java.io.Serializable;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.dto.TripNotificationEvent;
import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.service.TravelService;
import com.backpackcorp.backpack.replan.domain.PlanKey;
import com.backpackcorp.backpack.replan.domain.ReplanCondition;
import com.backpackcorp.backpack.replan.dto.ReplanApplyRequest;
import com.backpackcorp.backpack.replan.dto.ReplanRequest;
import com.backpackcorp.backpack.replan.dto.ReplanResponse;
import com.backpackcorp.backpack.schedule.domain.Schedule;
import com.backpackcorp.backpack.schedule.domain.ScheduleActivity;
import com.backpackcorp.backpack.schedule.dto.ScheduleResponse;
import com.backpackcorp.backpack.schedule.repository.ScheduleActivityRepository;
import com.backpackcorp.backpack.schedule.repository.ScheduleRepository;
import com.backpackcorp.backpack.schedule.service.ScheduleService;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.extern.slf4j.Slf4j;

// BP-AI-002 · 003 오늘 남은 일정 다시 짜기.
//   다시 짤 구간: 지금(또는 진행 중인 다른 일정이 끝나는 시각) ~ 그 뒤 처음 나오는 그대로 둘 일정(anchor, 보통 고정 일정)
//   추천: Gemini 키가 있으면 AI가 고른 순서 · 장소를 실제 이동 시간으로 다시 맞추고, 없거나 실패하면 규칙 기반 3안
//   적용: 추천 뒤 그날 일정이 바뀌지 않았을 때만 (버전 비교). 빠지는 일정은 지우고, 바뀐 일정에는 "재구성" 표시
@Slf4j
@Service
public class ReplanService {

	static final String CACHE = "replan";
	// anchor가 없을 때 다시 짤 구간의 끝
	static final LocalTime DAY_END = LocalTime.of(23, 0);
	private static final ExecutorService AI_EXECUTOR = Executors.newVirtualThreadPerTaskExecutor();

	private final TripMemberGuard tripMemberGuard;
	private final ScheduleRepository scheduleRepository;
	private final ScheduleActivityRepository activityRepository;
	private final ScheduleService scheduleService;
	private final TravelService travelService;
	private final AiPlanner aiPlanner;
	private final CacheManager cacheManager;
	private final ApplicationEventPublisher eventPublisher;
	private final TransactionTemplate readTransaction;
	private final Clock clock;
	// AI(Gemini + 새 장소 찾기)를 기다리는 최대 시간. 넘으면 이미 만든 규칙 기반 추천으로 답한다
	private final Duration aiBudget;

	public ReplanService(TripMemberGuard tripMemberGuard, ScheduleRepository scheduleRepository,
		ScheduleActivityRepository activityRepository, ScheduleService scheduleService, TravelService travelService,
		AiPlanner aiPlanner, CacheManager cacheManager, ApplicationEventPublisher eventPublisher,
		PlatformTransactionManager transactionManager, Clock clock,
		@Value("${ai.replan-timeout:30s}") Duration aiBudget) {
		this.tripMemberGuard = tripMemberGuard;
		this.scheduleRepository = scheduleRepository;
		this.activityRepository = activityRepository;
		this.scheduleService = scheduleService;
		this.travelService = travelService;
		this.aiPlanner = aiPlanner;
		this.cacheManager = cacheManager;
		this.eventPublisher = eventPublisher;
		this.readTransaction = new TransactionTemplate(transactionManager);
		this.readTransaction.setReadOnly(true);
		this.clock = clock;
		this.aiBudget = aiBudget;
	}

	// 외부 서버(경로 · AI)를 부르는 동안 DB 연결을 잡고 있지 않도록, DB는 prepare()에서만 읽는다
	public ReplanResponse recommend(UUID tripId, UUID userId, ReplanRequest request) {
		Prepared prepared = readTransaction.execute(status -> prepare(tripId, userId, request));
		RulePlanner.Input input = prepared.input();
		List<LatLng> points = new ArrayList<>();
		points.add(input.origin());
		input.targets().forEach(s -> points.add(s.place()));
		if (input.anchor() != null) {
			points.add(input.anchor().place());
		}
		TravelLookup travel = new TravelLookup(travelService, points);
		List<ReplanResponse.Plan> plans = RulePlanner.plans(input, travel);
		ReplanResponse.Source source = ReplanResponse.Source.RULE;
		String notice;
		if (!aiPlanner.available()) {
			notice = "AI 키가 설정되지 않아 기본 추천으로 만들었어요.";
		} else {
			List<ReplanResponse.Plan> rulePlans = plans;
			Future<List<ReplanResponse.Plan>> ai = AI_EXECUTOR.submit(() -> {
				List<AiPlanner.Draft> drafts = aiPlanner.suggest(prepared.aiContext());
				List<LatLng> all = new ArrayList<>(points);
				drafts.forEach(d -> d.stops().forEach(s -> all.add(s.place())));
				return merge(drafts, rulePlans, input, new TravelLookup(travelService, all));
			});
			try {
				List<ReplanResponse.Plan> merged = ai.get(aiBudget.toMillis(), TimeUnit.MILLISECONDS);
				boolean usedAi = !merged.equals(rulePlans);
				source = usedAi ? ReplanResponse.Source.AI : ReplanResponse.Source.RULE;
				notice = usedAi ? null : "AI 추천이 시간에 맞지 않아 기본 추천을 보여 드려요.";
				plans = merged;
			} catch (TimeoutException e) {
				ai.cancel(true);
				log.warn("AI 일정 재구성이 {}초를 넘어 규칙 기반 추천으로 대신", aiBudget.toSeconds());
				notice = "AI 응답이 늦어 기본 추천을 보여 드려요.";
			} catch (ExecutionException e) {
				log.warn("AI 일정 재구성 실패, 규칙 기반 추천으로 대신: {}", e.getCause().toString());
				notice = "AI 응답을 받지 못해 기본 추천을 보여 드려요.";
			} catch (InterruptedException e) {
				Thread.currentThread().interrupt();
				notice = "AI 응답을 받지 못해 기본 추천을 보여 드려요.";
			}
		}
		ReplanResponse response = new ReplanResponse(UUID.randomUUID(), source, notice, prepared.context(), plans);
		cache().put(response.requestId(), new Snapshot(tripId, prepared.day(), prepared.versions(),
			prepared.targetIds(), response));
		return response;
	}

	// AI 안을 실제 이동 시간으로 맞춘다. 하나도 담지 못한 안은 같은 기준의 규칙 기반 안으로 바꾼다
	private static List<ReplanResponse.Plan> merge(List<AiPlanner.Draft> drafts, List<ReplanResponse.Plan> rulePlans,
		RulePlanner.Input input, RulePlanner.Travel travel) {
		Map<PlanKey, AiPlanner.Draft> byKey = drafts.stream()
			.collect(Collectors.toMap(AiPlanner.Draft::key, Function.identity(), (a, b) -> a));
		List<ReplanResponse.Plan> merged = new ArrayList<>();
		for (ReplanResponse.Plan rule : rulePlans) {
			AiPlanner.Draft draft = byKey.get(rule.key());
			if (draft == null || draft.stops().isEmpty()) {
				merged.add(rule);
				continue;
			}
			ReplanResponse.Plan fitted = RulePlanner.fit(rule.key(), draft.stops(), input, travel, true, null);
			if (fitted.items().isEmpty()) {
				merged.add(rule);
				continue;
			}
			// AI가 고른 일정이 모두 들어갔을 때만 AI의 설명을 쓴다 (아니면 실제 결과로 만든 설명)
			if (draft.reason() != null && fitted.items().size() == draft.stops().size()) {
				fitted = RulePlanner.fit(rule.key(), draft.stops(), input, travel, true, draft.reason());
			}
			merged.add(RulePlanner.withDropped(fitted, input));
		}
		return merged;
	}

	@Transactional
	public List<ScheduleResponse> apply(UUID tripId, UUID userId, ReplanApplyRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Snapshot snapshot = snapshot(request.requestId());
		if (snapshot == null || !snapshot.tripId().equals(tripId)) {
			throw new BaseException(ErrorCode.REPLAN_EXPIRED);
		}
		ReplanResponse.Plan plan = snapshot.response().plans().stream()
			.filter(p -> p.key() == request.planKey())
			.findFirst()
			.orElseThrow(() -> new BaseException(ErrorCode.REPLAN_EXPIRED));

		List<Schedule> day = scheduleRepository.findByTripIdAndDayOrderByStartTime(tripId, snapshot.day());
		boolean doneSince = !activityRepository.findByScheduleIdIn(snapshot.targetIds()).isEmpty();
		if (!versionsOf(day).equals(snapshot.versions()) || doneSince) {
			throw new BaseException(ErrorCode.REPLAN_STALE);
		}
		Map<UUID, Schedule> byId = day.stream().collect(Collectors.toMap(Schedule::getId, Function.identity()));
		Instant at = clock.instant();
		for (ReplanResponse.Dropped dropped : plan.dropped()) {
			scheduleRepository.delete(byId.get(dropped.scheduleId()));
		}
		for (ReplanResponse.Item item : plan.items()) {
			Schedule schedule = item.scheduleId() != null
				? byId.get(item.scheduleId())
				: scheduleRepository.save(Schedule.builder()
					.trip(me.getTrip())
					.day(snapshot.day())
					.startTime(item.startTime())
					.endTime(item.endTime())
					.title(item.title())
					.placeText(item.placeText())
					.place(item.lat() == null ? null : new LatLng(item.lat(), item.lng()))
					.placeCategory(item.category())
					.memo("AI 일정 재구성으로 넣은 일정")
					.createdBy(me)
					.build());
			schedule.changeTime(snapshot.day(), item.startTime(), item.endTime());
			schedule.markReplanned(at);
		}
		scheduleRepository.flush();
		requireNoOverlap(scheduleRepository.findByTripIdAndDayOrderByStartTime(tripId, snapshot.day()));
		cache().evict(request.requestId());

		String message = MemberRef.nameOf(me) + "님이 " + snapshot.day().getMonthValue() + "."
			+ String.format("%02d", snapshot.day().getDayOfMonth()) + " 남은 일정을 다시 짰어요 (" + plan.label() + ")";
		eventPublisher.publishEvent(TripNotificationEvent.of(me.getTrip(), me, NotificationType.SCHEDULE_CHANGED,
			message, NotificationRefType.TRIP, tripId));
		return scheduleService.getSchedules(tripId, userId, snapshot.day());
	}

	private Prepared prepare(UUID tripId, UUID userId, ReplanRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		ZonedDateTime local = ZonedDateTime.now(clock.withZone(trip.zoneId()));
		LocalDate today = local.toLocalDate();
		LocalTime now = local.toLocalTime().truncatedTo(ChronoUnit.MINUTES);
		if (!trip.contains(today)) {
			throw new BaseException(ErrorCode.REPLAN_NOT_TODAY);
		}
		List<Schedule> day = scheduleRepository.findByTripIdAndDayOrderByStartTime(tripId, today);
		Map<UUID, ScheduleActivity> activities = activityRepository
			.findByScheduleIdIn(day.stream().map(Schedule::getId).toList())
			.stream()
			.collect(Collectors.toMap(a -> a.getSchedule().getId(), Function.identity()));
		Set<UUID> targetIds = new LinkedHashSet<>(request.scheduleIds());
		Map<UUID, Schedule> byId = day.stream().collect(Collectors.toMap(Schedule::getId, Function.identity()));
		for (UUID id : targetIds) {
			Schedule s = byId.get(id);
			if (s == null) {
				throw BaseException.of(ErrorCode.REPLAN_INVALID_TARGET, "scheduleId", id + " (오늘 일정이 아니에요)");
			}
			if (s.isLocked() || activities.containsKey(id)) {
				throw BaseException.of(ErrorCode.REPLAN_INVALID_TARGET, "scheduleId",
					"'" + s.getTitle() + "'은(는) " + (s.isLocked() ? "고정 일정이에요" : "이미 끝난 일정이에요"));
			}
		}
		List<Schedule> targets = day.stream().filter(s -> targetIds.contains(s.getId())).toList();

		// 진행 중인 다른 일정이 있으면 그 일정이 끝난 뒤부터 다시 짠다
		LocalTime start = now;
		for (Schedule s : day) {
			if (!targetIds.contains(s.getId()) && !activities.containsKey(s.getId())
				&& !s.getStartTime().isAfter(now) && s.getEndTime().isAfter(now) && s.getEndTime().isAfter(start)) {
				start = s.getEndTime();
			}
		}
		LocalTime windowStart = start;
		Schedule anchor = day.stream()
			.filter(s -> !targetIds.contains(s.getId()) && !activities.containsKey(s.getId()))
			.filter(s -> !s.getStartTime().isBefore(windowStart))
			.findFirst()
			.orElse(null);
		if (anchor != null) {
			targets.stream().filter(s -> s.getStartTime().isAfter(anchor.getStartTime())).findFirst().ifPresent(s -> {
				throw BaseException.of(ErrorCode.REPLAN_INVALID_TARGET, "scheduleId", "'" + anchor.getTitle()
					+ "' 뒤의 '" + s.getTitle() + "'은(는) 함께 다시 짤 수 없어요. '" + anchor.getTitle() + "'도 고르거나 그 전 일정만 골라 주세요.");
			});
		}
		LocalTime windowEnd = anchor != null ? anchor.getStartTime() : DAY_END;

		// 지금 있는 곳: 보낸 값 → 마지막으로 끝낸 일정 → 진행 중 일정
		LatLng origin = null;
		String originName = null;
		boolean fromGps = false;
		ReplanRequest.CurrentPlace current = request.currentPlace();
		if (current != null) {
			originName = current.name().trim();
			origin = current.lat() == null || current.lng() == null ? null : new LatLng(current.lat(), current.lng());
			fromGps = current.fromGps();
		} else {
			Schedule last = day.stream()
				.filter(s -> activities.containsKey(s.getId()) || !s.getStartTime().isAfter(now))
				.filter(s -> !targetIds.contains(s.getId()) && s.place() != null)
				.reduce((a, b) -> b)
				.orElse(null);
			if (last != null) {
				origin = last.place();
				originName = last.getPlaceText() != null ? last.getPlaceText() : last.getTitle();
			}
		}

		Set<ReplanCondition> conditions = request.conditions() == null || request.conditions().isEmpty()
			? EnumSet.noneOf(ReplanCondition.class)
			: EnumSet.copyOf(request.conditions());
		List<Stop> stops = targets.stream().map(ReplanService::stopOf).toList();
		Stop anchorStop = anchor == null ? null : stopOf(anchor);
		RulePlanner.Input input = new RulePlanner.Input(windowStart, windowEnd, origin, stops, anchorStop,
			conditions);

		int delay = activities.values().stream().mapToInt(ScheduleActivity::getDelayMin).sum();
		ReplanResponse.Anchor anchorView = anchor == null ? null : new ReplanResponse.Anchor(anchor.getId(),
			anchor.getTitle(), anchor.getPlaceText(), anchor.getStartTime(), anchor.isLocked(),
			Duration.between(now, anchor.getStartTime()).toMinutes());
		ReplanResponse.Context context = new ReplanResponse.Context(originName, fromGps, now, windowStart, windowEnd,
			activities.size(), delay, anchorView);
		AiPlanner.Context aiContext = new AiPlanner.Context(trip.getDestination(), now.toString(),
			windowStart.toString(), windowEnd.toString(), originName, origin, anchorStop, stops, conditions);
		return new Prepared(today, input, context, aiContext, versionsOf(day), List.copyOf(targetIds));
	}

	private static Stop stopOf(Schedule s) {
		int stay = (int)Duration.between(s.getStartTime(), s.getEndTime()).toMinutes();
		return new Stop(s.getId(), s.getTitle(), s.getPlaceText(), s.place(), s.getPlaceCategory(), stay, false);
	}

	private static HashMap<UUID, Integer> versionsOf(List<Schedule> day) {
		HashMap<UUID, Integer> versions = new HashMap<>();
		day.forEach(s -> versions.put(s.getId(), s.getVersion()));
		return versions;
	}

	// 적용 결과를 한 번 더 확인한다. 겹치면 되돌린다 (트랜잭션 롤백)
	private static void requireNoOverlap(List<Schedule> day) {
		for (int i = 0; i < day.size(); i++) {
			for (int j = i + 1; j < day.size(); j++) {
				if (day.get(j).overlaps(day.get(i).getStartTime(), day.get(i).getEndTime())) {
					throw new BaseException(ErrorCode.REPLAN_STALE);
				}
			}
		}
	}

	private Snapshot snapshot(UUID requestId) {
		try {
			return cache().get(requestId, Snapshot.class);
		} catch (RuntimeException e) {
			log.warn("재구성 추천을 불러오지 못했어요: {}", e.toString());
			return null;
		}
	}

	private Cache cache() {
		Cache cache = cacheManager.getCache(CACHE);
		if (cache == null) {
			throw new IllegalStateException("캐시 " + CACHE + "가 없어요");
		}
		return cache;
	}

	private record Prepared(
		LocalDate day,
		RulePlanner.Input input,
		ReplanResponse.Context context,
		AiPlanner.Context aiContext,
		HashMap<UUID, Integer> versions,
		List<UUID> targetIds
	) {
	}

	// 적용할 때 비교할 그때의 일정 버전과 추천안
	record Snapshot(
		UUID tripId,
		LocalDate day,
		HashMap<UUID, Integer> versions,
		List<UUID> targetIds,
		ReplanResponse response
	) implements Serializable {
	}
}
