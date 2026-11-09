package com.backpackcorp.backpack.budget.repository;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.budget.domain.ExchangeRate;

public interface ExchangeRateRepository extends JpaRepository<ExchangeRate, UUID> {

	// 그 날짜의 값이 없으면(주말·공휴일·수집 실패) 가장 가까운 이전 날짜 값을 쓴다
	Optional<ExchangeRate> findFirstByCurrencyCodeAndRateDateLessThanEqualOrderByRateDateDesc(String currencyCode,
		LocalDate rateDate);

	Optional<ExchangeRate> findByCurrencyCodeAndRateDate(String currencyCode, LocalDate rateDate);
}
