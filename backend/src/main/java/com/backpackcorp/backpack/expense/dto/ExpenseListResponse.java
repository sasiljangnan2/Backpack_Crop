package com.backpackcorp.backpack.expense.dto;

import java.util.List;

import com.backpackcorp.backpack.budget.dto.ExchangeRateResponse;

// 지출 목록 (커서 방식) + 화면 상단의 공동 지출 합계와 환율 기준.
// summary는 페이지와 상관없이 필터(date·category)에 맞는 전체 지출의 합계다
public record ExpenseListResponse(
	List<ExpenseListItemResponse> content,
	String nextCursor,
	boolean hasNext,
	Summary summary
) {

	// todayRate: 여행 통화의 오늘 환율. 여행 통화가 KRW이거나 환율 정보가 없으면 null
	public record Summary(
		long count,
		long totalKrw,
		String currencyCode,
		ExchangeRateResponse todayRate
	) {
	}
}
