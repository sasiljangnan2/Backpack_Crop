package com.backpackcorp.backpack.budget.service;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.budget.dto.AppliedRate;
import com.backpackcorp.backpack.budget.dto.ExchangeRateResponse;
import com.backpackcorp.backpack.budget.repository.ExchangeRateRepository;
import com.backpackcorp.backpack.budget.service.rate.ExchangeRateCollector;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;

import lombok.RequiredArgsConstructor;

// 환율 조회. exchange_rates에 날짜별로 쌓인 값을 읽고, 없으면 ExchangeRateCollector가 외부 출처에서 가져온다.
// 외부 출처도 실패하면 가장 가까운 이전 날짜 값으로 대체한다
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ExchangeRateService {

	public static final String KRW = "KRW";
	// 환율은 한국 은행 고시 기준이므로 "오늘"도 한국 날짜로 정한다
	public static final ZoneId RATE_ZONE = ZoneId.of("Asia/Seoul");
	// 100단위로 고시·표시하는 통화
	private static final Set<String> PER_100_CURRENCIES = Set.of("JPY", "IDR", "VND");

	private final ExchangeRateRepository exchangeRateRepository;
	private final ExchangeRateCollector exchangeRateCollector;
	private final Clock clock;

	public ExchangeRateResponse getRate(String currencyCode, LocalDate date) {
		String code = normalize(currencyCode);
		LocalDate requested = date != null ? date : today();
		return ExchangeRateResponse.of(findRate(code, requested), requested, displayUnit(code));
	}

	// 지출 계산용. 없으면 EXCHANGE_RATE_NOT_FOUND
	public AppliedRate findRate(String currencyCode, LocalDate date) {
		return findRateOrEmpty(currencyCode, date)
			.orElseThrow(() -> BaseException.of(ErrorCode.EXCHANGE_RATE_NOT_FOUND, "currencyCode", currencyCode));
	}

	// 화면 보조 정보(지출 목록의 "오늘 환율")처럼 없어도 되는 곳에서 쓴다
	public Optional<ExchangeRateResponse> findTodayRate(String currencyCode) {
		LocalDate today = today();
		return findRateOrEmpty(currencyCode, today)
			.map(rate -> ExchangeRateResponse.of(rate, today, displayUnit(currencyCode)));
	}

	public LocalDate today() {
		return LocalDate.now(clock.withZone(RATE_ZONE));
	}

	// 1) 그 날짜 값이 DB에 있으면 그 값  2) 없으면 외부 출처에서 가져와 저장  3) 그래도 없으면 가장 가까운 이전 값.
	// 미래 날짜(여행 전에 미리 입력한 지출)는 오늘 값으로 계산한다
	private Optional<AppliedRate> findRateOrEmpty(String currencyCode, LocalDate date) {
		if (KRW.equals(currencyCode)) {
			return Optional.of(new AppliedRate(KRW, BigDecimal.ONE.setScale(6), date, null));
		}
		LocalDate today = today();
		LocalDate lookup = date.isAfter(today) ? today : date;
		Optional<AppliedRate> stored = exchangeRateRepository
			.findFirstByCurrencyCodeAndRateDateLessThanEqualOrderByRateDateDesc(currencyCode, lookup)
			.map(rate -> new AppliedRate(rate.getCurrencyCode(), rate.getRateToKrw(), rate.getRateDate(),
				rate.getFetchedAt()));
		if (stored.isPresent() && stored.get().rateDate().equals(lookup)) {
			return stored;
		}
		Optional<AppliedRate> fetched = exchangeRateCollector.collect(currencyCode, lookup);
		if (fetched.isPresent() && (stored.isEmpty() || !fetched.get().rateDate().isBefore(stored.get().rateDate()))) {
			return fetched;
		}
		return stored;
	}

	private static String normalize(String currencyCode) {
		String code = currencyCode == null ? "" : currencyCode.trim().toUpperCase(Locale.ROOT);
		if (!code.matches("[A-Z]{3}")) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "currencyCode", "통화 코드는 영문 3자리로 입력해 주세요.");
		}
		return code;
	}

	private static int displayUnit(String currencyCode) {
		return PER_100_CURRENCIES.contains(currencyCode) ? 100 : 1;
	}
}
