package com.backpackcorp.backpack.budget.service.rate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import lombok.extern.slf4j.Slf4j;

// 한국수출입은행 현재환율 API (매매기준율). 국내 은행 고시 환율이라 가장 먼저 쓴다.
// 인증키(exchange-rate.exim-api-key)가 있을 때만 켜진다. 키는 https://www.koreaexim.go.kr 에서 무료로 받는다.
// 영업일 11시 전후에 그날 값이 올라오고, 주말·공휴일·고시 전에는 빈 목록이 온다 (그때는 다음 출처로 넘어간다)
@Slf4j
@Component
@Order(10)
@ConditionalOnExpression("!'${exchange-rate.exim-api-key:}'.isBlank()")
public class KoreaEximRateProvider implements ExchangeRateProvider {

	private static final DateTimeFormatter SEARCH_DATE = DateTimeFormatter.ofPattern("yyyyMMdd");
	private static final ParameterizedTypeReference<List<Map<String, Object>>> JSON =
		new ParameterizedTypeReference<>() {
		};

	private final RestClient client;
	private final String apiKey;

	public KoreaEximRateProvider(@Value("${exchange-rate.exim-api-key}") String apiKey,
		@Value("${exchange-rate.exim-url:https://oapi.koreaexim.go.kr/site/program/financial}") String baseUrl) {
		this.client = RateHttp.client(baseUrl);
		this.apiKey = apiKey;
	}

	@Override
	public String name() {
		return "koreaexim";
	}

	@Override
	public Optional<FetchedRate> fetch(String currencyCode, LocalDate date) {
		try {
			List<Map<String, Object>> body = client.get()
				.uri("/exchangeJSON?authkey={key}&searchdate={date}&data=AP01", apiKey, date.format(SEARCH_DATE))
				.retrieve()
				.body(JSON);
			return parse(body, currencyCode, date);
		} catch (RestClientException e) {
			log.debug("수출입은행 환율 조회 실패: {} {} - {}", currencyCode, date, e.getMessage());
			return Optional.empty();
		}
	}

	// cur_unit은 "USD" 또는 "JPY(100)"처럼 100단위로 고시되는 통화가 있다 → 1단위로 바꿔 저장한다
	static Optional<FetchedRate> parse(List<Map<String, Object>> body, String currencyCode, LocalDate date) {
		if (body == null) {
			return Optional.empty();
		}
		for (Map<String, Object> row : body) {
			Object unit = row.get("cur_unit");
			if (unit == null || !"1".equals(String.valueOf(row.get("result")))) {
				continue;
			}
			String code = unit.toString().trim();
			int divisor = 1;
			int paren = code.indexOf('(');
			if (paren > 0) {
				divisor = Integer.parseInt(code.substring(paren + 1, code.indexOf(')')).trim());
				code = code.substring(0, paren).trim();
			}
			if (!code.equals(currencyCode)) {
				continue;
			}
			BigDecimal rate = RateHttp.positive(row.get("deal_bas_r"));
			if (rate == null) {
				return Optional.empty();
			}
			return Optional.of(new FetchedRate(date,
				rate.divide(BigDecimal.valueOf(divisor), 6, RoundingMode.HALF_UP)));
		}
		return Optional.empty();
	}
}
