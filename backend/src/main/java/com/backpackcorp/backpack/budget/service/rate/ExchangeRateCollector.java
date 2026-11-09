package com.backpackcorp.backpack.budget.service.rate;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import com.backpackcorp.backpack.budget.domain.ExchangeRate;
import com.backpackcorp.backpack.budget.dto.AppliedRate;
import com.backpackcorp.backpack.budget.repository.ExchangeRateRepository;

import lombok.extern.slf4j.Slf4j;

// 외부 출처에서 환율을 가져와 exchange_rates에 쌓는다. 출처는 @Order 순서대로 시도한다
// (수출입은행 → ECB(frankfurter) → open.er-api). 저장한 값은 다시 바뀌지 않으므로 DB가 곧 캐시다.
// 같은 (통화, 날짜)를 한 번 물은 뒤에는 한동안 결과를 기억한다 (고시 전 아침에 요청이 몰려도 외부 API를 두드리지 않는다)
@Slf4j
@Component
public class ExchangeRateCollector {

	private static final Duration RETRY_AFTER_FAILURE = Duration.ofMinutes(30);
	private static final Duration RETRY_EARLIER_DATE = Duration.ofHours(3);

	private final List<ExchangeRateProvider> providers;
	private final ExchangeRateRepository exchangeRateRepository;
	private final TransactionTemplate newTransaction;
	private final Clock clock;
	private final boolean enabled;
	private final Map<String, Attempt> attempts = new ConcurrentHashMap<>();

	public ExchangeRateCollector(List<ExchangeRateProvider> providers, ExchangeRateRepository exchangeRateRepository,
		PlatformTransactionManager transactionManager, Clock clock,
		@Value("${exchange-rate.fetch-enabled:true}") boolean enabled) {
		this.providers = providers;
		this.exchangeRateRepository = exchangeRateRepository;
		this.newTransaction = new TransactionTemplate(transactionManager);
		this.newTransaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
		this.clock = clock;
		this.enabled = enabled;
	}

	// 가져와 저장한 값. 출처가 그 날짜보다 이른 날짜의 값을 줄 수 있다 (주말이면 금요일 값 → rateDate 확인)
	public Optional<AppliedRate> collect(String currencyCode, LocalDate date) {
		if (!enabled) {
			return Optional.empty();
		}
		String key = currencyCode + "|" + date;
		Instant now = Instant.now(clock);
		Attempt previous = attempts.get(key);
		if (previous != null && previous.until().isAfter(now)) {
			return previous.result();
		}
		for (ExchangeRateProvider provider : providers) {
			Optional<ExchangeRateProvider.FetchedRate> fetched = provider.fetch(currencyCode, date);
			if (fetched.isPresent() && !fetched.get().rateDate().isAfter(date)) {
				AppliedRate saved = save(currencyCode, fetched.get(), provider.name());
				// 그 날짜 값이면 DB에서 바로 찾으므로 다시 물을 일이 없다. 이전 날짜 값이면 그날 고시될 때까지 가끔 다시 묻는다
				if (!saved.rateDate().equals(date)) {
					attempts.put(key, new Attempt(Optional.of(saved), now.plus(RETRY_EARLIER_DATE)));
				}
				return Optional.of(saved);
			}
		}
		attempts.put(key, new Attempt(Optional.empty(), now.plus(RETRY_AFTER_FAILURE)));
		log.info("환율을 가져오지 못했습니다: {} {}", currencyCode, date);
		return Optional.empty();
	}

	private record Attempt(Optional<AppliedRate> result, Instant until) {
	}

	// 호출한 쪽이 읽기 전용 트랜잭션이어도 저장되도록 새 트랜잭션에서 저장한다.
	// 이미 같은 (통화, 날짜) 값이 있으면 그 값을 쓴다 (지난 지출과 금액이 어긋나지 않게 덮어쓰지 않는다)
	private AppliedRate save(String currencyCode, ExchangeRateProvider.FetchedRate fetched, String source) {
		try {
			ExchangeRate saved = newTransaction.execute(status -> exchangeRateRepository
				.findByCurrencyCodeAndRateDate(currencyCode, fetched.rateDate())
				.orElseGet(() -> exchangeRateRepository.save(ExchangeRate.builder()
					.currencyCode(currencyCode)
					.rateDate(fetched.rateDate())
					.rateToKrw(fetched.rateToKrw())
					.build())));
			log.info("환율 저장: {} {} = {} ({})", currencyCode, saved.getRateDate(), saved.getRateToKrw(), source);
			return new AppliedRate(currencyCode, saved.getRateToKrw(), saved.getRateDate(), saved.getFetchedAt());
		} catch (DataIntegrityViolationException e) {
			// 같은 값을 동시에 저장하려 한 경우. 먼저 저장된 값을 쓴다
			ExchangeRate existing = newTransaction.execute(status -> exchangeRateRepository
				.findByCurrencyCodeAndRateDate(currencyCode, fetched.rateDate()).orElseThrow());
			return new AppliedRate(currencyCode, existing.getRateToKrw(), existing.getRateDate(),
				existing.getFetchedAt());
		}
	}
}
