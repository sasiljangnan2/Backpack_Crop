package com.backpackcorp.backpack.replan.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.replan.dto.ReplanApplyRequest;
import com.backpackcorp.backpack.replan.dto.ReplanRequest;
import com.backpackcorp.backpack.replan.dto.ReplanResponse;
import com.backpackcorp.backpack.replan.service.ReplanService;
import com.backpackcorp.backpack.schedule.dto.ScheduleResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}/replan")
public class ReplanController {

	private final ReplanService replanService;

	// BP-AI-002 추천 3안 받기
	@PostMapping
	public ReplanResponse recommend(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@Valid @RequestBody ReplanRequest request) {
		return replanService.recommend(tripId, BackpackUserDetails.requireId(user), request);
	}

	// BP-AI-003 이 안으로 적용 → 그날 일정 전체
	@PostMapping("/apply")
	public List<ScheduleResponse> apply(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@Valid @RequestBody ReplanApplyRequest request) {
		return replanService.apply(tripId, BackpackUserDetails.requireId(user), request);
	}
}
