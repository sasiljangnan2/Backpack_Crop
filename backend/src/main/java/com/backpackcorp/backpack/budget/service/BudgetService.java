package com.backpackcorp.backpack.budget.service;

import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.budget.domain.BudgetItem;
import com.backpackcorp.backpack.budget.dto.BudgetItemRequest;
import com.backpackcorp.backpack.budget.dto.BudgetItemUpdateRequest;
import com.backpackcorp.backpack.budget.dto.BudgetResponse;
import com.backpackcorp.backpack.budget.dto.ExchangeRateResponse;
import com.backpackcorp.backpack.budget.repository.BudgetItemRepository;
import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.dto.CategoryAmountDto;
import com.backpackcorp.backpack.expense.repository.ExpenseRepository;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.RequiredArgsConstructor;

// 예산 (BP-BG). 항목은 원화 또는 여행 통화로 넣고, 현황은 원화로 모아 분류별 지출과 비교한다
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BudgetService {

	private final TripMemberGuard tripMemberGuard;
	private final TripMemberRepository tripMemberRepository;
	private final BudgetItemRepository budgetItemRepository;
	private final ExpenseRepository expenseRepository;
	private final ExchangeRateService exchangeRateService;

	public BudgetResponse getBudget(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		ExchangeRateResponse todayRate = ExchangeRateService.KRW.equals(trip.getCurrencyCode())
			? null
			: exchangeRateService.findTodayRate(trip.getCurrencyCode()).orElse(null);

		Map<ExpenseCategory, long[]> byCategory = new EnumMap<>(ExpenseCategory.class);
		boolean unconverted = false;
		long totalBudget = 0;
		List<BudgetResponse.Item> items = new ArrayList<>();
		for (BudgetItem item : budgetItemRepository.findByTripIdOrderById(tripId)) {
			Long krw = toKrw(item, todayRate);
			if (krw == null) {
				unconverted = true;
			} else {
				totalBudget += krw;
				byCategory.computeIfAbsent(item.getCategory(), c -> new long[2])[0] += krw;
			}
			items.add(new BudgetResponse.Item(item.getId(), item.getCategory(), item.getName(), item.getAmount(),
				item.getCurrencyCode(), krw, item.getCreatedAt()));
		}
		long totalSpent = 0;
		for (CategoryAmountDto spent : expenseRepository.sumByCategory(tripId)) {
			byCategory.computeIfAbsent(spent.category(), c -> new long[2])[1] += spent.amount();
			totalSpent += spent.amount();
		}
		List<BudgetResponse.CategorySummary> summary = byCategory.entrySet().stream()
			.map(e -> new BudgetResponse.CategorySummary(e.getKey(), e.getValue()[0], e.getValue()[1]))
			.toList();
		int members = (int)tripMemberRepository.countByTripIdAndLeftAtIsNull(tripId);
		long perPerson = members == 0 ? 0 : Math.ceilDiv(totalBudget, members);
		return new BudgetResponse(items, summary, totalBudget, totalSpent, members, perPerson,
			trip.getCurrencyCode(), todayRate, unconverted);
	}

	@Transactional
	public BudgetResponse.Item createItem(UUID tripId, UUID userId, BudgetItemRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		BudgetItem item = budgetItemRepository.save(BudgetItem.builder()
			.trip(trip)
			.category(request.category())
			.name(request.name().trim())
			.amount(request.amount().setScale(2))
			.currencyCode(currency(trip, request.currencyCode()))
			.build());
		return toItem(trip, item);
	}

	@Transactional
	public BudgetResponse.Item updateItem(UUID tripId, UUID itemId, UUID userId, BudgetItemUpdateRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		BudgetItem item = findItem(tripId, itemId);
		if (request.name() != null && request.name().isBlank()) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "name", "항목 이름을 입력해 주세요.");
		}
		item.update(
			request.category() != null ? request.category() : item.getCategory(),
			request.name() != null ? request.name().trim() : item.getName(),
			request.amount() != null ? request.amount().setScale(2) : item.getAmount(),
			request.currencyCode() != null ? currency(trip, request.currencyCode()) : item.getCurrencyCode());
		return toItem(trip, item);
	}

	@Transactional
	public void deleteItem(UUID tripId, UUID itemId, UUID userId) {
		tripMemberGuard.requireMember(tripId, userId);
		budgetItemRepository.delete(findItem(tripId, itemId));
	}

	private BudgetItem findItem(UUID tripId, UUID itemId) {
		return budgetItemRepository.findByIdAndTripId(itemId, tripId)
			.orElseThrow(() -> new BaseException(ErrorCode.BUDGET_ITEM_NOT_FOUND));
	}

	private BudgetResponse.Item toItem(Trip trip, BudgetItem item) {
		ExchangeRateResponse rate = ExchangeRateService.KRW.equals(item.getCurrencyCode())
			? null
			: exchangeRateService.findTodayRate(trip.getCurrencyCode()).orElse(null);
		return new BudgetResponse.Item(item.getId(), item.getCategory(), item.getName(), item.getAmount(),
			item.getCurrencyCode(), toKrw(item, rate), item.getCreatedAt());
	}

	private static Long toKrw(BudgetItem item, ExchangeRateResponse rate) {
		if (ExchangeRateService.KRW.equals(item.getCurrencyCode())) {
			return item.getAmount().setScale(0, RoundingMode.HALF_UP).longValueExact();
		}
		if (rate == null) {
			return null;
		}
		return item.getAmount().multiply(rate.rateToKrw()).setScale(0, RoundingMode.HALF_UP).longValueExact();
	}

	private static String currency(Trip trip, String code) {
		String upper = code.trim().toUpperCase(Locale.ROOT);
		if (!upper.equals(ExchangeRateService.KRW) && !upper.equals(trip.getCurrencyCode())) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "currencyCode",
				"원화(KRW) 또는 여행 통화(" + trip.getCurrencyCode() + ")로 입력해 주세요.");
		}
		return upper;
	}
}
