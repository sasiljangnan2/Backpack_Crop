package com.backpackcorp.backpack.expense.controller;

import java.time.LocalDate;
import java.util.UUID;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.dto.ExpenseDetailResponse;
import com.backpackcorp.backpack.expense.dto.ExpenseListResponse;
import com.backpackcorp.backpack.expense.dto.ExpenseRequest;
import com.backpackcorp.backpack.expense.service.ExpenseService;
import com.backpackcorp.backpack.global.security.BackpackUserDetails;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}/expenses")
public class ExpenseController {

	private final ExpenseService expenseService;

	// BP-EX-001 지출 목록 + 공동 지출 합계 + 환율 기준
	@GetMapping
	public ExpenseListResponse getExpenses(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId,
		@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
		@RequestParam(required = false) ExpenseCategory category,
		@RequestParam(required = false) String cursor,
		@RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
		return expenseService.getExpenses(tripId, BackpackUserDetails.requireId(user), date, category, cursor, size);
	}

	// BP-EX-004 등록 + 분담 계산
	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public ExpenseDetailResponse createExpense(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @Valid @RequestBody ExpenseRequest request) {
		return expenseService.createExpense(tripId, BackpackUserDetails.requireId(user), request);
	}

	// BP-EX-003 · 004 저장 전 계산 결과 (원화 환산, 1인 몫, 끝전 부담자)
	@PostMapping("/preview")
	public ExpenseDetailResponse previewExpense(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @Valid @RequestBody ExpenseRequest request) {
		return expenseService.previewExpense(tripId, BackpackUserDetails.requireId(user), request);
	}

	// BP-EX-005 지출 상세
	@GetMapping("/{expenseId}")
	public ExpenseDetailResponse getExpense(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID expenseId) {
		return expenseService.getExpense(tripId, expenseId, BackpackUserDetails.requireId(user));
	}

	// 전체 교체 (등록과 같은 바디 + version). 결제자 · 작성자 · 방장만
	@PutMapping("/{expenseId}")
	public ExpenseDetailResponse updateExpense(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID expenseId, @Valid @RequestBody ExpenseRequest request) {
		return expenseService.updateExpense(tripId, expenseId, BackpackUserDetails.requireId(user), request);
	}

	@DeleteMapping("/{expenseId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void deleteExpense(@AuthenticationPrincipal BackpackUserDetails user,
		@PathVariable UUID tripId, @PathVariable UUID expenseId) {
		expenseService.deleteExpense(tripId, expenseId, BackpackUserDetails.requireId(user));
	}
}
