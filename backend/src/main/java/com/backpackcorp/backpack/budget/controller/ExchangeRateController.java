package com.backpackcorp.backpack.budget.controller;

import java.time.LocalDate;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.budget.dto.ExchangeRateResponse;
import com.backpackcorp.backpack.budget.service.ExchangeRateService;

import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/exchange-rates")
public class ExchangeRateController {

	private final ExchangeRateService exchangeRateService;

	// GET /api/exchange-rates?currencyCode=JPY&date=2026-11-01 (date 생략 시 오늘)
	// currency는 역할 분담 문서의 이름. 두 이름을 모두 받는다
	@GetMapping
	public ExchangeRateResponse getRate(
		@RequestParam(required = false) String currencyCode,
		@RequestParam(required = false) String currency,
		@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
		return exchangeRateService.getRate(currencyCode != null ? currencyCode : currency, date);
	}
}
