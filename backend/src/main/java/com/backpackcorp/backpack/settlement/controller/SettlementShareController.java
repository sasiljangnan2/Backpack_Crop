package com.backpackcorp.backpack.settlement.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.settlement.dto.SettlementShareResponse;
import com.backpackcorp.backpack.settlement.service.SettlementShareService;

import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}/settlement-shares")
public class SettlementShareController {

	private final SettlementShareService settlementShareService;

	// 지금의 송금 경로를 저장한다. 주고받을 돈이 없으면 409 NOTHING_TO_SETTLE
	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public SettlementShareResponse share(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId) {
		return settlementShareService.share(tripId, BackpackUserDetails.requireId(user));
	}

	@GetMapping
	public List<SettlementShareResponse.Summary> getShares(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId) {
		return settlementShareService.getShares(tripId, BackpackUserDetails.requireId(user));
	}

	@GetMapping("/{shareId}")
	public SettlementShareResponse getShare(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID shareId) {
		return settlementShareService.getShare(tripId, shareId, BackpackUserDetails.requireId(user));
	}
}
