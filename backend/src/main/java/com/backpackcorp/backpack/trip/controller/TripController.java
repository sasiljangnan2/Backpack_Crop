package com.backpackcorp.backpack.trip.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.trip.dto.TripCreateRequest;
import com.backpackcorp.backpack.trip.dto.TripDetailResponse;
import com.backpackcorp.backpack.trip.dto.TripJoinRequest;
import com.backpackcorp.backpack.trip.dto.TripMemberResponse;
import com.backpackcorp.backpack.trip.dto.TripSummaryResponse;
import com.backpackcorp.backpack.trip.service.TripService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

// 모든 메서드가 로그인한 사용자를 쓰므로 SecurityConfig에서 이 경로들은 토큰이 있어야 들어온다
@RestController
@RequestMapping("/api/trips")
@RequiredArgsConstructor
public class TripController {

	private final TripService tripService;

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public TripDetailResponse createTrip(@AuthenticationPrincipal BackpackUserDetails user,
		@Valid @RequestBody TripCreateRequest request) {
		return tripService.createTrip(user.getId(), request);
	}

	@GetMapping
	public List<TripSummaryResponse> getMyTrips(@AuthenticationPrincipal BackpackUserDetails user) {
		return tripService.getMyTrips(user.getId());
	}

	// @PathVariable: 주소의 {tripId} 자리에 들어온 값
	@GetMapping("/{tripId}")
	public TripDetailResponse getTrip(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId) {
		return tripService.getTrip(tripId, user.getId());
	}

	@PostMapping("/join")
	public TripDetailResponse joinTrip(@AuthenticationPrincipal BackpackUserDetails user,
		@Valid @RequestBody TripJoinRequest request) {
		return tripService.joinTrip(user.getId(), request);
	}

	@GetMapping("/{tripId}/members")
	public List<TripMemberResponse> getMembers(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId) {
		return tripService.getMembers(tripId, user.getId());
	}
}
