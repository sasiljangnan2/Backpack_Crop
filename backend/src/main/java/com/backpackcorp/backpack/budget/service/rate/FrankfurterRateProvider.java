package com.backpackcorp.backpack.budget.service.rate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import lombok.extern.slf4j.Slf4j;

// 유럽중앙은행(ECB) 기준 환율 (frankfurter.dev, 키 없음). 과거 날짜도 조회할 수 있다.
// 주말·공휴일을 요청하면 직전 영업일 값과 그 날짜를 준다. ECB가 다루지 않는 통화(VND 등)는 비어 있다
@Slf4j
@Component
@Order(20)
public class FrankfurterRateProvider implements ExchangeRateProvider {

	private static final ParameterizedTypeReference<Map<String, Object>> JSON = new ParameterizedTypeReference<>() {
	};

	private final RestClient client;

	public FrankfurterRateProvider(
		@Value("${exchange-rate.frankfurter-url:https://api.frankfurter.dev/v1}") String baseUrl) {
		this.client = RateHttp.client(baseUrl);
	}

	@Override
	public String name() {
		return "frankfurter";
	}

	@Override
	public Optional<FetchedRate> fetch(String currencyCode, LocalDate date) {
		try {
			Map<String, Object> body = client.get()
				.uri("/{date}?base={base}&symbols=KRW", date.toString(), currencyCode)
				.retrieve()
				.body(JSON);
			return parse(body);
		} catch (RestClientException e) {
			log.debug("frankfurter 환율 조회 실패: {} {} - {}", currencyCode, date, e.getMessage());
			return Optional.empty();
		}
	}

	@SuppressWarnings("unchecked")
	static Optional<FetchedRate> parse(Map<String, Object> body) {
		if (body == null || !(body.get("rates") instanceof Map<?, ?> rates) || body.get("date") == null) {
			return Optional.empty();
		}
		BigDecimal rate = RateHttp.positive(((Map<String, Object>)rates).get("KRW"));
		if (rate == null) {
			return Optional.empty();
		}
		return Optional.of(new FetchedRate(LocalDate.parse(body.get("date").toString()),
			rate.setScale(6, RoundingMode.HALF_UP)));
	}
}
