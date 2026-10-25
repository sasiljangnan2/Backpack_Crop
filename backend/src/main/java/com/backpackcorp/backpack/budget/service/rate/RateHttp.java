package com.backpackcorp.backpack.budget.service.rate;

import java.math.BigDecimal;
import java.net.http.HttpClient;
import java.time.Duration;

import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

// 환율 출처들이 함께 쓰는 HTTP 설정. 외부 API가 느려도 지출 등록이 오래 매달리지 않게 짧게 끊는다
final class RateHttp {

	private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(2);
	private static final Duration READ_TIMEOUT = Duration.ofSeconds(4);

	private RateHttp() {
	}

	static RestClient client(String baseUrl) {
		HttpClient httpClient = HttpClient.newBuilder()
			.connectTimeout(CONNECT_TIMEOUT)
			.followRedirects(HttpClient.Redirect.NORMAL)
			.build();
		JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
		factory.setReadTimeout(READ_TIMEOUT);
		return RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
	}

	// "1,382.5" 같은 문자열도 숫자로 바꾼다. 0 이하·형식 오류는 null
	static BigDecimal positive(Object value) {
		if (value == null) {
			return null;
		}
		try {
			BigDecimal number = new BigDecimal(value.toString().replace(",", "").trim());
			return number.signum() > 0 ? number : null;
		} catch (NumberFormatException e) {
			return null;
		}
	}
}
