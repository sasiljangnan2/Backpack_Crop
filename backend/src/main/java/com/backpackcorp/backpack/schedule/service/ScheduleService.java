package com.backpackcorp.backpack.schedule.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.dto.TripNotificationEvent;
import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.schedule.domain.ReservationStatus;
import com.backpackcorp.backpack.schedule.domain.Schedule;
import com.backpackcorp.backpack.schedule.domain.ScheduleActivity;
import com.backpackcorp.backpack.schedule.dto.ActivityRequest;
import com.backpackcorp.backpack.schedule.dto.ScheduleCreateRequest;
import com.backpackcorp.backpack.schedule.dto.ScheduleResponse;
import com.backpackcorp.backpack.schedule.dto.ScheduleStatus;
import com.backpackcorp.backpack.schedule.dto.ScheduleUpdateRequest;
import com.backpackcorp.backpack.schedule.dto.TodayResponse;
import com.backpackcorp.backpack.schedule.repository.ScheduleActivityRepository;
import com.backpackcorp.backpack.schedule.repository.ScheduleRepository;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripStatus;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.RequiredArgsConstructor;

// 일정 CRUD · 활동 기록 · 오늘 요약.
// 규칙
//   시간: 종료 > 시작 (자정을 넘는 일정은 두 개로 나눈다), 날짜는 여행 기간 안
//   겹침: 같은 날에 new.start < old.end AND new.end > old.start 인 일정이 있으면 SCHEDULE_OVERLAP
//   고정: 고정된 일정은 고정을 먼저 풀어야 고치거나 지울 수 있다 (SCHEDULE_LOCKED)
//   버전: 수정 요청의 version이 현재 값과 다르면 VERSION_CONFLICT
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ScheduleService {

	private final TripMemberGuard tripMemberGuard;
	private final ScheduleRepository scheduleRepository;
	private final ScheduleActivityRepository scheduleActivityRepository;
	private final ApplicationEventPublisher eventPublisher;
	private final Clock clock;

	// BP-SC-001 날짜별 일정. day가 null이면 전체
	public List<ScheduleResponse> getSchedules(UUID tripId, UUID userId, LocalDate day) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		List<Schedule> schedules = scheduleRepository.findByTrip(tripId, day);
		return toResponses(me.getTrip(), schedules);
	}

	public ScheduleResponse getSchedule(UUID tripId, UUID scheduleId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		return toResponse(me.getTrip(), findSchedule(tripId, scheduleId));
	}

	@Transactional
	public ScheduleResponse createSchedule(UUID tripId, UUID userId, ScheduleCreateRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		LocalTime start = minutes(request.startTime());
		LocalTime end = minutes(request.endTime());
		validateTime(trip, request.day(), start, end);
		checkOverlap(tripId, request.day(), start, end, null);

		Schedule schedule = scheduleRepository.save(Schedule.builder()
			.trip(trip)
			.day(request.day())
			.startTime(start)
			.endTime(end)
			.title(request.title().trim())
			.placeText(blankToNull(request.placeText()))
			.memo(blankToNull(request.memo()))
			.reservationStatus(request.reservationStatus())
			.locked(request.isLocked())
			.createdBy(me)
			.build());
		notifyChange(me, schedule, "추가했어요", NotificationRefType.SCHEDULE, schedule.getId());
		return toResponse(trip, schedule);
	}

	@Transactional
	public ScheduleResponse updateSchedule(UUID tripId, UUID scheduleId, UUID userId, ScheduleUpdateRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		Schedule schedule = findSchedule(tripId, scheduleId);
		if (schedule.getVersion() != request.version()) {
			throw BaseException.of(ErrorCode.VERSION_CONFLICT, "version", String.valueOf(schedule.getVersion()));
		}
		if (schedule.isLocked()) {
			// 고정된 일정에 허용하는 요청은 "고정 풀기" 하나뿐이다
			if (request.changesOtherThanLock() || !Boolean.FALSE.equals(request.isLocked())) {
				throw BaseException.of(ErrorCode.SCHEDULE_LOCKED, "scheduleId", schedule.getId().toString());
			}
			schedule.changeLocked(false);
			scheduleRepository.flush();
			notifyChange(me, schedule, "고정을 풀었어요", NotificationRefType.SCHEDULE, schedule.getId());
			return toResponse(trip, schedule);
		}

		LocalDate day = request.day() != null ? request.day() : schedule.getDay();
		LocalTime start = request.startTime() != null ? minutes(request.startTime()) : schedule.getStartTime();
		LocalTime end = request.endTime() != null ? minutes(request.endTime()) : schedule.getEndTime();
		boolean timeChanged = !day.equals(schedule.getDay()) || !start.equals(schedule.getStartTime())
			|| !end.equals(schedule.getEndTime());
		if (timeChanged) {
			validateTime(trip, day, start, end);
			checkOverlap(tripId, day, start, end, schedule.getId());
			schedule.changeTime(day, start, end);
		}

		String title = request.title() != null ? notBlank(request.title()) : schedule.getTitle();
		String placeText = request.placeText() != null ? blankToNull(request.placeText()) : schedule.getPlaceText();
		String memo = request.memo() != null ? blankToNull(request.memo()) : schedule.getMemo();
		ReservationStatus reservation = request.reservationStatus() != null
			? request.reservationStatus()
			: schedule.getReservationStatus();
		schedule.changeDetails(title, placeText, memo, reservation);
		if (request.isLocked() != null) {
			schedule.changeLocked(request.isLocked());
		}
		// 응답의 version이 이번 수정을 반영하도록 먼저 반영한다
		scheduleRepository.flush();
		notifyChange(me, schedule, "수정했어요", NotificationRefType.SCHEDULE, schedule.getId());
		return toResponse(trip, schedule);
	}

	// BP-SC-003
	@Transactional
	public void deleteSchedule(UUID tripId, UUID scheduleId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Schedule schedule = findSchedule(tripId, scheduleId);
		if (schedule.isLocked()) {
			throw BaseException.of(ErrorCode.SCHEDULE_LOCKED, "scheduleId", schedule.getId().toString());
		}
		// 지운 일정으로는 이동할 수 없으므로 알림은 여행(일정 탭)을 가리킨다
		notifyChange(me, schedule, "삭제했어요", NotificationRefType.TRIP, tripId);
		// 활동 기록은 DB의 ON DELETE CASCADE로 함께 지워진다
		scheduleRepository.delete(schedule);
	}

	// BP-AI-004 활동 기록. 다시 기록하면 덮어쓴다. 고정 여부와 상관없이 기록할 수 있다
	@Transactional
	public ScheduleResponse recordActivity(UUID tripId, UUID scheduleId, UUID userId, ActivityRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Schedule schedule = findSchedule(tripId, scheduleId);
		LocalTime start = minutes(request.actualStartTime());
		LocalTime end = minutes(request.actualEndTime());
		if (end.isBefore(start)) {
			throw BaseException.of(ErrorCode.INVALID_TIME_RANGE, "actualEndTime", "실제 종료는 실제 시작과 같거나 늦어야 해요.");
		}
		ScheduleActivity activity = scheduleActivityRepository.findByScheduleId(schedule.getId())
			.map(existing -> {
				existing.record(me, start, end);
				return existing;
			})
			.orElseGet(() -> scheduleActivityRepository.save(ScheduleActivity.builder().schedule(schedule)
				.recordedBy(me).actualStartTime(start).actualEndTime(end).build()));
		Now now = now(me.getTrip());
		return ScheduleResponse.of(schedule, activity, now.date(), now.time());
	}

	@Transactional
	public void cancelActivity(UUID tripId, UUID scheduleId, UUID userId) {
		tripMemberGuard.requireMember(tripId, userId);
		Schedule schedule = findSchedule(tripId, scheduleId);
		scheduleActivityRepository.findByScheduleId(schedule.getId()).ifPresent(scheduleActivityRepository::delete);
	}

	// BP-AI-001 · HM-001(여행 중) 오늘 요약
	public TodayResponse getToday(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		Now now = now(trip);
		List<Schedule> schedules = scheduleRepository.findByTrip(tripId, now.date());
		Map<UUID, ScheduleActivity> activities = activitiesOf(schedules);
		List<ScheduleResponse> responses = schedules.stream()
			.map(s -> ScheduleResponse.of(s, activities.get(s.getId()), now.date(), now.time()))
			.toList();

		ScheduleResponse current = responses.stream()
			.filter(s -> s.status() == ScheduleStatus.IN_PROGRESS)
			.findFirst()
			.orElse(null);
		ScheduleResponse next = responses.stream()
			.filter(s -> s.status() == ScheduleStatus.PLANNED && s.startTime().isAfter(now.time()))
			.findFirst()
			.orElse(null);
		TodayResponse.NextFixed nextFixed = responses.stream()
			.filter(s -> s.isLocked() && s.status() == ScheduleStatus.PLANNED && s.startTime().isAfter(now.time()))
			.findFirst()
			.map(s -> new TodayResponse.NextFixed(s, Duration.between(now.time(), s.startTime()).toMinutes()))
			.orElse(null);
		int delay = activities.values().stream().mapToInt(ScheduleActivity::getDelayMin).sum();
		int done = (int)responses.stream().filter(s -> s.status() == ScheduleStatus.DONE).count();

		TripStatus tripStatus = trip.statusOn(now.date());
		Integer dayNo = tripStatus == TripStatus.LIVE
			? (int)ChronoUnit.DAYS.between(trip.getStartDate(), now.date()) + 1
			: null;
		return new TodayResponse(now.date(), now.time(), trip.getTimeZone(), now.instant(), tripStatus, dayNo, current,
			next, nextFixed, delay, done, responses.size(), responses.size() - done, responses);
	}

	// 투표 마감으로 일정을 만든다 (BP-VT). 검증은 직접 추가할 때와 같고, 알림은 투표 쪽에서 한 번만 보낸다
	@Transactional
	public Schedule createFromPoll(TripMember actor, LocalDate day, LocalTime start, LocalTime end, String title,
		String memo) {
		Trip trip = actor.getTrip();
		validateTime(trip, day, start, end);
		checkOverlap(trip.getId(), day, start, end, null);
		return scheduleRepository.save(Schedule.builder()
			.trip(trip)
			.day(day)
			.startTime(start)
			.endTime(end)
			.title(title)
			.memo(memo)
			.createdBy(actor)
			.build());
	}

	private void notifyChange(TripMember actor, Schedule schedule, String action, NotificationRefType refType,
		UUID refId) {
		String message = MemberRef.nameOf(actor) + "님이 " + schedule.getDay().getMonthValue() + "."
			+ String.format("%02d", schedule.getDay().getDayOfMonth()) + " '" + schedule.getTitle() + "' 일정을 "
			+ action;
		eventPublisher.publishEvent(TripNotificationEvent.of(actor.getTrip(), actor, NotificationType.SCHEDULE_CHANGED,
			message, refType, refId));
	}

	// ---- 검증 ----

	private static void validateTime(Trip trip, LocalDate day, LocalTime start, LocalTime end) {
		if (!trip.contains(day)) {
			throw BaseException.of(ErrorCode.SCHEDULE_OUT_OF_TRIP, "day",
				trip.getStartDate() + " ~ " + trip.getEndDate() + " 사이의 날짜를 선택해 주세요.");
		}
		if (!end.isAfter(start)) {
			throw BaseException.of(ErrorCode.INVALID_TIME_RANGE, "endTime", "종료 시간은 시작 시간보다 늦어야 해요.");
		}
	}

	// 투표를 열 때: 반영할 시간이 이미 다른 일정과 겹치면 409 SCHEDULE_OVERLAP
	public void requireFreeSlot(UUID tripId, LocalDate day, LocalTime start, LocalTime end) {
		checkOverlap(tripId, day, start, end, null);
	}

	// 겹친 일정 중 가장 이른 것을 details에 담는다. overlapCount는 겹친 일정 수
	private void checkOverlap(UUID tripId, LocalDate day, LocalTime start, LocalTime end, UUID excludeId) {
		List<Schedule> overlapping = scheduleRepository.findByTripIdAndDayOrderByStartTime(tripId, day).stream()
			.filter(other -> !other.getId().equals(excludeId))
			.filter(other -> other.overlaps(start, end))
			.toList();
		if (overlapping.isEmpty()) {
			return;
		}
		Schedule first = overlapping.getFirst();
		Map<String, String> details = new LinkedHashMap<>();
		details.put("scheduleId", first.getId().toString());
		details.put("title", first.getTitle());
		details.put("day", first.getDay().toString());
		details.put("startTime", first.getStartTime().toString());
		details.put("endTime", first.getEndTime().toString());
		details.put("overlapCount", String.valueOf(overlapping.size()));
		throw new BaseException(ErrorCode.SCHEDULE_OVERLAP, details);
	}

	// ---- 조회 도우미 ----

	private Schedule findSchedule(UUID tripId, UUID scheduleId) {
		return scheduleRepository.findInTrip(scheduleId, tripId)
			.orElseThrow(() -> new BaseException(ErrorCode.SCHEDULE_NOT_FOUND));
	}

	private ScheduleResponse toResponse(Trip trip, Schedule schedule) {
		Optional<ScheduleActivity> activity = scheduleActivityRepository.findByScheduleId(schedule.getId());
		Now now = now(trip);
		return ScheduleResponse.of(schedule, activity.orElse(null), now.date(), now.time());
	}

	private List<ScheduleResponse> toResponses(Trip trip, List<Schedule> schedules) {
		Map<UUID, ScheduleActivity> activities = activitiesOf(schedules);
		Now now = now(trip);
		return schedules.stream()
			.map(s -> ScheduleResponse.of(s, activities.get(s.getId()), now.date(), now.time()))
			.toList();
	}

	private Map<UUID, ScheduleActivity> activitiesOf(List<Schedule> schedules) {
		if (schedules.isEmpty()) {
			return Map.of();
		}
		return scheduleActivityRepository.findByScheduleIdIn(schedules.stream().map(Schedule::getId).toList())
			.stream()
			.collect(Collectors.toMap(a -> a.getSchedule().getId(), Function.identity()));
	}

	private Now now(Trip trip) {
		ZonedDateTime local = ZonedDateTime.now(clock.withZone(trip.zoneId()));
		return new Now(local.toLocalDate(), local.toLocalTime().truncatedTo(ChronoUnit.MINUTES), local.toInstant());
	}

	private static LocalTime minutes(LocalTime time) {
		return time.truncatedTo(ChronoUnit.MINUTES);
	}

	private static String blankToNull(String value) {
		return value == null || value.isBlank() ? null : value.trim();
	}

	private static String notBlank(String value) {
		if (value.isBlank()) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "title", "일정 이름을 입력해 주세요.");
		}
		return value.trim();
	}

	private record Now(LocalDate date, LocalTime time, Instant instant) {
	}
}
