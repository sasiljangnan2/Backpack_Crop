package com.backpackcorp.backpack.budget.service.rate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

import com.backpackcorp.backpack.budget.domain.ExchangeRate;
import com.backpackcorp.backpack.budget.dto.AppliedRate;
import com.backpackcorp.backpack.budget.repository.ExchangeRateRepository;

// 외부 응답 해석과 수집 순서. 실제 네트워크는 부르지 않는다
class ExchangeRateProviderTest {

	private static final LocalDate FRIDAY = LocalDate.of(2026, 10, 23);
	private static final LocalDate SATURDAY = FRIDAY.plusDays(1);

	@Test
	void frankfurter_응답에서_원화_환율과_고시_날짜를_읽는다() {
		Optional<ExchangeRateProvider.FetchedRate> rate = FrankfurterRateProvider.parse(
			Map.of("amount", 1.0, "base", "JPY", "date", "2026-10-23", "rates", Map.of("KRW", 8.4466)));

		assertThat(rate).contains(new ExchangeRateProvider.FetchedRate(FRIDAY, new BigDecimal("8.446600")));
		assertThat(FrankfurterRateProvider.parse(Map.of("message", "not found"))).isEmpty();
	}

	@Test
	void open_er_api_응답은_갱신_시각의_날짜를_쓴다() {
		Optional<ExchangeRateProvider.FetchedRate> rate = OpenErApiRateProvider.parse(Map.of("result", "success",
			"time_last_update_unix", 1792800151L, "rates", Map.of("KRW", 1, "VND", 18.5)));

		assertThat(rate.orElseThrow().rateDate()).isEqualTo(LocalDate.of(2026, 10, 24));
		assertThat(OpenErApiRateProvider.parse(Map.of("result", "error"))).isEmpty();
	}

	@Test
	void 수출입은행의_100단위_통화는_1단위로_바꾼다() {
		List<Map<String, Object>> body = List.of(
			Map.of("result", 1, "cur_unit", "USD", "deal_bas_r", "1,382.5"),
			Map.of("result", 1, "cur_unit", "JPY(100)", "deal_bas_r", "935.81"));

		assertThat(KoreaEximRateProvider.parse(body, "JPY", FRIDAY).orElseThrow().rateToKrw())
			.isEqualByComparingTo("9.3581");
		assertThat(KoreaEximRateProvider.parse(body, "USD", FRIDAY).orElseThrow().rateToKrw())
			.isEqualByComparingTo("1382.5");
		assertThat(KoreaEximRateProvider.parse(body, "EUR", FRIDAY)).isEmpty();
		assertThat(KoreaEximRateProvider.parse(List.of(), "USD", FRIDAY)).isEmpty();
	}

	@Test
	void 앞_출처가_실패하면_다음_출처를_쓰고_한_번_실패한_요청은_잠시_다시_묻지_않는다() {
		ExchangeRateProvider first = provider("first", Optional.empty());
		ExchangeRateProvider second = provider("second",
			Optional.of(new ExchangeRateProvider.FetchedRate(FRIDAY, new BigDecimal("9.350000"))));
		ExchangeRateRepository repository = repository();
		ExchangeRateCollector collector = collector(List.of(first, second), repository);

		Optional<AppliedRate> rate = collector.collect("JPY", SATURDAY);

		// 토요일을 물었지만 금요일 값이 왔다
		assertThat(rate.orElseThrow().rateDate()).isEqualTo(FRIDAY);
		verify(repository).save(any(ExchangeRate.class));

		ExchangeRateProvider failing = provider("failing", Optional.empty());
		ExchangeRateCollector failingCollector = collector(List.of(failing), repository());
		assertThat(failingCollector.collect("VND", FRIDAY)).isEmpty();
		assertThat(failingCollector.collect("VND", FRIDAY)).isEmpty();
		verify(failing, times(1)).fetch("VND", FRIDAY);
	}

	@Test
	void 출처가_요청한_날짜보다_늦은_값을_주면_쓰지_않는다() {
		ExchangeRateProvider future = provider("future",
			Optional.of(new ExchangeRateProvider.FetchedRate(SATURDAY, BigDecimal.TEN)));
		ExchangeRateRepository repository = repository();

		assertThat(collector(List.of(future), repository).collect("JPY", FRIDAY)).isEmpty();
		verify(repository, never()).save(any(ExchangeRate.class));
	}

	private static ExchangeRateProvider provider(String name, Optional<ExchangeRateProvider.FetchedRate> result) {
		ExchangeRateProvider provider = mock(ExchangeRateProvider.class);
		when(provider.name()).thenReturn(name);
		when(provider.fetch(any(), any())).thenReturn(result);
		return provider;
	}

	private static ExchangeRateRepository repository() {
		ExchangeRateRepository repository = mock(ExchangeRateRepository.class);
		when(repository.findByCurrencyCodeAndRateDate(any(), any())).thenReturn(Optional.empty());
		when(repository.save(any(ExchangeRate.class))).thenAnswer(call -> call.getArgument(0));
		return repository;
	}

	private static ExchangeRateCollector collector(List<ExchangeRateProvider> providers,
		ExchangeRateRepository repository) {
		PlatformTransactionManager tx = mock(PlatformTransactionManager.class);
		when(tx.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
		Clock clock = Clock.fixed(Instant.parse("2026-10-24T03:00:00Z"), ZoneOffset.UTC);
		return new ExchangeRateCollector(providers, repository, tx, clock, true);
	}
}
