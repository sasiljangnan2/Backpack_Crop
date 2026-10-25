package com.backpackcorp.backpack.schedule.controller;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.schedule.dto.ActivityRequest;
import com.backpackcorp.backpack.schedule.dto.ScheduleCreateRequest;
import com.backpackcorp.backpack.schedule.dto.ScheduleResponse;
import com.backpackcorp.backpack.schedule.dto.ScheduleUpdateRequest;
import com.backpackcorp.backpack.schedule.dto.TodayResponse;
import com.backpackcorp.backpack.schedule.service.ScheduleService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}")
public class ScheduleController {

	private final ScheduleService scheduleService;

	// BP-SC-001 ?day=2026-11-01 (생략하면 전체)
	@GetMapping("/schedules")
	public List<ScheduleResponse> getSchedules(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId,
		@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate day) {
		return scheduleService.getSchedules(tripId, BackpackUserDetails.requireId(user), day);
	}

	@GetMapping("/schedules/{scheduleId}")
	public ScheduleResponse getSchedule(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID scheduleId) {
		return scheduleService.getSchedule(tripId, scheduleId, BackpackUserDetails.requireId(user));
	}

	// BP-SC-002
	@PostMapping("/schedules")
	@ResponseStatus(HttpStatus.CREATED)
	public ScheduleResponse createSchedule(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @Valid @RequestBody ScheduleCreateRequest request) {
		return scheduleService.createSchedule(tripId, BackpackUserDetails.requireId(user), request);
	}

	@PatchMapping("/schedules/{scheduleId}")
	public ScheduleResponse updateSchedule(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID scheduleId, @Valid @RequestBody ScheduleUpdateRequest request) {
		return scheduleService.updateSchedule(tripId, scheduleId, BackpackUserDetails.requireId(user), request);
	}

	// BP-SC-003
	@DeleteMapping("/schedules/{scheduleId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void deleteSchedule(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID scheduleId) {
		scheduleService.deleteSchedule(tripId, scheduleId, BackpackUserDetails.requireId(user));
	}

	// BP-AI-004 활동 기록 (POST는 역할 분담 문서의 이름, PUT과 같다)
	@RequestMapping(path = "/schedules/{scheduleId}/activity", method = {RequestMethod.PUT, RequestMethod.POST})
	public ScheduleResponse recordActivity(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID scheduleId, @Valid @RequestBody ActivityRequest request) {
		return scheduleService.recordActivity(tripId, scheduleId, BackpackUserDetails.requireId(user), request);
	}

	@DeleteMapping("/schedules/{scheduleId}/activity")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void cancelActivity(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID scheduleId) {
		scheduleService.cancelActivity(tripId, scheduleId, BackpackUserDetails.requireId(user));
	}

	// BP-AI-001 · HM-001(여행 중)
	@GetMapping("/today")
	public TodayResponse getToday(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId) {
		return scheduleService.getToday(tripId, BackpackUserDetails.requireId(user));
	}
}
