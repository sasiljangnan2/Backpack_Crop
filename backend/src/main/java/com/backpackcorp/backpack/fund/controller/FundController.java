package com.backpackcorp.backpack.fund.controller;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.fund.dto.FundContributionRequest;
import com.backpackcorp.backpack.fund.dto.FundResponse;
import com.backpackcorp.backpack.fund.service.FundService;
import com.backpackcorp.backpack.global.security.BackpackUserDetails;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

// 공금 현황과 모은 돈. 변경하면 바뀐 현황 전체를 돌려준다
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}/fund")
public class FundController {

	private final FundService fundService;

	@GetMapping
	public FundResponse get(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId) {
		return fundService.getFund(tripId, BackpackUserDetails.requireId(user));
	}

	@PostMapping("/contributions")
	@ResponseStatus(HttpStatus.CREATED)
	public FundResponse add(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@Valid @RequestBody FundContributionRequest request) {
		return fundService.addContribution(tripId, BackpackUserDetails.requireId(user), request);
	}

	@PutMapping("/contributions/{contributionId}")
	public FundResponse update(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID contributionId, @Valid @RequestBody FundContributionRequest request) {
		return fundService.updateContribution(tripId, contributionId, BackpackUserDetails.requireId(user), request);
	}

	@DeleteMapping("/contributions/{contributionId}")
	public FundResponse delete(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID contributionId) {
		return fundService.deleteContribution(tripId, contributionId, BackpackUserDetails.requireId(user));
	}
}
