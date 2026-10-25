package com.backpackcorp.backpack.budget.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.expense.domain.ExpenseCategory;

// BP-BG 예산 현황. 여행 통화 예산은 오늘 환율로 원화 환산한다 (todayRate).
// 환율이 없어 환산하지 못한 항목은 amountKrw가 null이고 합계에서 빠진다 (hasUnconvertedItems)
// perPersonBudgetKrw: 1인 준비 금액 = 전체 예산 ÷ 현재 멤버 수 (올림)
public record BudgetResponse(
	List<Item> items,
	List<CategorySummary> summary,
	long totalBudgetKrw,
	long totalSpentKrw,
	int memberCount,
	long perPersonBudgetKrw,
	String currencyCode,
	ExchangeRateResponse todayRate,
	boolean hasUnconvertedItems
) {

	public record Item(
		UUID id,
		ExpenseCategory category,
		String name,
		BigDecimal amount,
		String currencyCode,
		Long amountKrw,
		Instant createdAt
	) {
	}

	public record CategorySummary(
		ExpenseCategory category,
		long budgetKrw,
		long spentKrw
	) {
	}
}
