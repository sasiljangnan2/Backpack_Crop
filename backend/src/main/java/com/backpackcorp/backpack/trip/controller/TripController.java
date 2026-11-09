package com.backpackcorp.backpack.trip.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.trip.dto.JoinTripRequest;
import com.backpackcorp.backpack.trip.dto.PrepaidRateRequest;
import com.backpackcorp.backpack.trip.dto.TripCreateRequest;
import com.backpackcorp.backpack.trip.dto.TripDetailResponse;
import com.backpackcorp.backpack.trip.dto.TripMemberResponse;
import com.backpackcorp.backpack.trip.dto.TripSummaryResponse;
import com.backpackcorp.backpack.trip.dto.TripUpdateRequest;
import com.backpackcorp.backpack.trip.service.TripService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips")
public class TripController {

	private final TripService tripService;

	// BP-TR-002 여행 만들기 → 초대 코드 발급, 만든 사람이 방장
	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public TripDetailResponse createTrip(@AuthenticationPrincipal BackpackUserDetails user,
		@Valid @RequestBody TripCreateRequest request) {
		return tripService.createTrip(BackpackUserDetails.requireId(user), request);
	}

	// BP-TR-001 내 여행 목록
	@GetMapping
	public List<TripSummaryResponse> getMyTrips(@AuthenticationPrincipal BackpackUserDetails user) {
		return tripService.getMyTrips(BackpackUserDetails.requireId(user));
	}

	// BP-TR-003 초대 코드로 참여
	@PostMapping("/join")
	public TripDetailResponse joinTrip(@AuthenticationPrincipal BackpackUserDetails user,
		@Valid @RequestBody JoinTripRequest request) {
		return tripService.joinTrip(BackpackUserDetails.requireId(user), request.inviteCode());
	}

	// BP-HM-001 · HM-002 여행 상세 (초대 코드 포함)
	@GetMapping("/{tripId}")
	public TripDetailResponse getTrip(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId) {
		return tripService.getTrip(tripId, BackpackUserDetails.requireId(user));
	}

	// 방장만
	@PatchMapping("/{tripId}")
	public TripDetailResponse updateTrip(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @Valid @RequestBody TripUpdateRequest request) {
		return tripService.updateTrip(tripId, BackpackUserDetails.requireId(user), request);
	}

	// 방장만
	@DeleteMapping("/{tripId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void deleteTrip(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId) {
		tripService.deleteTrip(tripId, BackpackUserDetails.requireId(user));
	}

	@GetMapping("/{tripId}/members")
	public List<TripMemberResponse> getMembers(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId) {
		return tripService.getMembers(tripId, BackpackUserDetails.requireId(user));
	}

	@DeleteMapping("/{tripId}/members/me")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void leaveTrip(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId) {
		tripService.leaveTrip(tripId, BackpackUserDetails.requireId(user));
	}

	@PatchMapping("/{tripId}/members/me/prepaid-rate")
	public TripMemberResponse changePrepaidRate(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @Valid @RequestBody PrepaidRateRequest request) {
		return tripService.changePrepaidRate(tripId, BackpackUserDetails.requireId(user), request);
	}
}
