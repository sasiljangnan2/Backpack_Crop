package com.backpackcorp.backpack.settlement.controller;

import java.util.UUID;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.settlement.dto.MySettlementResponse;
import com.backpackcorp.backpack.settlement.dto.SettlementResponse;
import com.backpackcorp.backpack.settlement.service.SettlementService;

import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}/settlement")
public class SettlementController {

	private final SettlementService settlementService;

	// BP-ST-001 사람별 잔액 + 송금 경로
	@GetMapping
	public SettlementResponse getSettlement(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId) {
		return settlementService.getSettlement(tripId, BackpackUserDetails.requireId(user));
	}

	// BP-ST-002 계산 근거 · 홈 카드
	@GetMapping("/me")
	public MySettlementResponse getMySettlement(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId) {
		return settlementService.getMySettlement(tripId, BackpackUserDetails.requireId(user));
	}
}
