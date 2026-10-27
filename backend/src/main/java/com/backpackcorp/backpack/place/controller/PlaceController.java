package com.backpackcorp.backpack.place.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.dto.PlaceResponse;
import com.backpackcorp.backpack.place.dto.TravelLeg;
import com.backpackcorp.backpack.place.service.PlaceService;
import com.backpackcorp.backpack.place.service.TravelService;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;

// 지도용 장소 · 이동 시간 (OpenStreetMap). 로그인한 사용자만 쓴다 (공용 서버를 대신 부르므로)
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/places")
public class PlaceController {

	private final PlaceService placeService;
	private final TravelService travelService;

	// ?q=구로몬 시장&tripId=... (여행지 근처 먼저) 또는 &lat=..&lng=.. (그 근처 먼저)
	@GetMapping("/search")
	public List<PlaceResponse> search(@AuthenticationPrincipal BackpackUserDetails user,
		@RequestParam @NotBlank(message = "검색어를 입력해 주세요.") @Size(max = 100) String q,
		@RequestParam(required = false) UUID tripId,
		@RequestParam(required = false) @DecimalMin("-90") @DecimalMax("90") Double lat,
		@RequestParam(required = false) @DecimalMin("-180") @DecimalMax("180") Double lng) {
		LatLng near = lat == null || lng == null ? null : new LatLng(lat, lng);
		return placeService.search(q, tripId, near, BackpackUserDetails.requireId(user));
	}

	// BP-AI-002 "AI가 읽은 현재 상황"의 현재 장소. 찾지 못하면 204
	@GetMapping("/reverse")
	public ResponseEntity<PlaceResponse> reverse(
		@RequestParam @DecimalMin("-90") @DecimalMax("90") double lat,
		@RequestParam @DecimalMin("-180") @DecimalMax("180") double lng) {
		PlaceResponse place = placeService.reverse(new LatLng(lat, lng));
		return place == null ? ResponseEntity.noContent().build() : ResponseEntity.ok(place);
	}

	// BP-SC-004 장소 카드 "현재 위치에서 도보 12분 · 900m"
	@GetMapping("/travel")
	public TravelLeg travel(
		@RequestParam @DecimalMin("-90") @DecimalMax("90") double fromLat,
		@RequestParam @DecimalMin("-180") @DecimalMax("180") double fromLng,
		@RequestParam @DecimalMin("-90") @DecimalMax("90") double toLat,
		@RequestParam @DecimalMin("-180") @DecimalMax("180") double toLng) {
		return travelService.leg(new LatLng(fromLat, fromLng), new LatLng(toLat, toLng));
	}
}
