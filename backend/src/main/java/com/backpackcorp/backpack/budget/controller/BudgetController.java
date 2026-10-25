package com.backpackcorp.backpack.budget.controller;

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

import com.backpackcorp.backpack.budget.dto.BudgetItemRequest;
import com.backpackcorp.backpack.budget.dto.BudgetItemUpdateRequest;
import com.backpackcorp.backpack.budget.dto.BudgetResponse;
import com.backpackcorp.backpack.budget.service.BudgetService;
import com.backpackcorp.backpack.global.security.BackpackUserDetails;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}/budget-items")
public class BudgetController {

	private final BudgetService budgetService;

	// 예산 항목 + 분류별 예산 대비 지출 + 1인 준비 금액
	@GetMapping
	public BudgetResponse getBudget(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId) {
		return budgetService.getBudget(tripId, BackpackUserDetails.requireId(user));
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public BudgetResponse.Item createItem(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @Valid @RequestBody BudgetItemRequest request) {
		return budgetService.createItem(tripId, BackpackUserDetails.requireId(user), request);
	}

	@PatchMapping("/{itemId}")
	public BudgetResponse.Item updateItem(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID itemId, @Valid @RequestBody BudgetItemUpdateRequest request) {
		return budgetService.updateItem(tripId, itemId, BackpackUserDetails.requireId(user), request);
	}

	@DeleteMapping("/{itemId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void deleteItem(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID itemId) {
		budgetService.deleteItem(tripId, itemId, BackpackUserDetails.requireId(user));
	}
}
