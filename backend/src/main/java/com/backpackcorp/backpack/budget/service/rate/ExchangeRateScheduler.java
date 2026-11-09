package com.backpackcorp.backpack.budget.service.rate;

import java.time.Clock;
import java.time.LocalDate;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.backpackcorp.backpack.budget.service.ExchangeRateService;
import com.backpackcorp.backpack.trip.repository.TripRepository;

import lombok.extern.slf4j.Slf4j;

// 정해진 시각마다 오늘 환율을 미리 받아 둔다. 사용자가 지출을 등록할 때 외부 API를 기다리지 않게 한다.
// 대상: 기본 통화 목록 + 아직 끝나지 않았거나 최근에 끝난 여행의 통화
@Slf4j
@Component
@ConditionalOnProperty(name = "exchange-rate.fetch-enabled", havingValue = "true", matchIfMissing = true)
public class ExchangeRateScheduler {

	// 끝난 지 이만큼 지난 여행의 통화는 더 받지 않는다 (뒤늦은 지출 입력은 과거 날짜 조회로 처리된다)
	private static final int RECENT_TRIP_DAYS = 14;

	private final ExchangeRateCollector collector;
	private final TripRepository tripRepository;
	private final List<String> defaultCurrencies;
	private final Clock clock;

	public ExchangeRateScheduler(ExchangeRateCollector collector, TripRepository tripRepository,
		@Value("${exchange-rate.default-currencies:JPY,USD,EUR}") List<String> defaultCurrencies, Clock clock) {
		this.collector = collector;
		this.tripRepository = tripRepository;
		this.defaultCurrencies = defaultCurrencies;
		this.clock = clock;
	}

	@Scheduled(cron = "${exchange-rate.collect-cron:0 20 */2 * * *}", zone = "Asia/Seoul")
	public void collectToday() {
		LocalDate today = LocalDate.now(clock.withZone(ExchangeRateService.RATE_ZONE));
		Set<String> currencies = new LinkedHashSet<>(defaultCurrencies);
		currencies.addAll(tripRepository.findCurrenciesInUse(today.minusDays(RECENT_TRIP_DAYS)));
		currencies.remove(ExchangeRateService.KRW);
		int saved = 0;
		for (String currency : currencies) {
			if (collector.collect(currency.trim(), today).isPresent()) {
				saved++;
			}
		}
		log.info("환율 수집: {}개 통화 중 {}개 확인", currencies.size(), saved);
	}
}
