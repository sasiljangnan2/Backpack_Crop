package com.backpackcorp.backpack.budget.service.rate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import lombok.extern.slf4j.Slf4j;

// ExchangeRate-API 공개 엔드포인트 (open.er-api.com, 키 없음, 하루 1번 갱신, 160여 개 통화).
// 최신 값만 주므로 최근 날짜를 요청할 때만 쓴다. ECB가 다루지 않는 통화(VND, TWD 등)의 대체 출처다.
// 이용 조건: 앱이나 문서에 출처(https://www.exchangerate-api.com)를 표시한다
@Slf4j
@Component
@Order(30)
public class OpenErApiRateProvider implements ExchangeRateProvider {

	// 이보다 오래된 날짜는 최신 값으로 대신하지 않는다
	private static final int MAX_AGE_DAYS = 3;
	private static final ParameterizedTypeReference<Map<String, Object>> JSON = new ParameterizedTypeReference<>() {
	};

	private final RestClient client;
	private final Clock clock;

	public OpenErApiRateProvider(@Value("${exchange-rate.open-er-api-url:https://open.er-api.com/v6}") String baseUrl,
		Clock clock) {
		this.client = RateHttp.client(baseUrl);
		this.clock = clock;
	}

	@Override
	public String name() {
		return "open-er-api";
	}

	@Override
	public Optional<FetchedRate> fetch(String currencyCode, LocalDate date) {
		if (date.isBefore(LocalDate.now(clock).minusDays(MAX_AGE_DAYS))) {
			return Optional.empty();
		}
		try {
			Map<String, Object> body = client.get().uri("/latest/{base}", currencyCode).retrieve().body(JSON);
			return parse(body).filter(rate -> !rate.rateDate().isAfter(date));
		} catch (RestClientException e) {
			log.debug("open.er-api 환율 조회 실패: {} - {}", currencyCode, e.getMessage());
			return Optional.empty();
		}
	}

	@SuppressWarnings("unchecked")
	static Optional<FetchedRate> parse(Map<String, Object> body) {
		if (body == null || !"success".equals(body.get("result"))
			|| !(body.get("rates") instanceof Map<?, ?> rates)) {
			return Optional.empty();
		}
		BigDecimal rate = RateHttp.positive(((Map<String, Object>)rates).get("KRW"));
		Object updated = body.get("time_last_update_unix");
		if (rate == null || updated == null) {
			return Optional.empty();
		}
		LocalDate rateDate = Instant.ofEpochSecond(Long.parseLong(updated.toString()))
			.atOffset(ZoneOffset.UTC)
			.toLocalDate();
		return Optional.of(new FetchedRate(rateDate, rate.setScale(6, RoundingMode.HALF_UP)));
	}
}
