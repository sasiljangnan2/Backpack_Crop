package com.backpackcorp.backpack.global.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.context.annotation.Import;
import org.springframework.stereotype.Component;
import org.springframework.test.context.ActiveProfiles;

class CacheConfigTest {

	@Nested
	@SpringBootTest
	@ActiveProfiles("test")
	@Import(Rates.class)
	class 캐시가_정상일_때 {

		@Autowired
		private Rates rates;

		@Test
		void 두_번째_호출은_캐시된_값을_돌려준다() {
			assertThat(rates.find("JPY")).isEqualTo("JPY:1");
			assertThat(rates.find("JPY")).isEqualTo("JPY:1");
		}
	}

	@Nested
	// 아무도 듣지 않는 포트로 Redis 캐시를 붙여 장애 상황을 만든다
	@SpringBootTest(properties = {"spring.cache.type=redis", "spring.data.redis.port=1"})
	@ActiveProfiles("test")
	@Import(Rates.class)
	class Redis에_연결할_수_없을_때 {

		@Autowired
		private Rates rates;

		@Test
		void 예외_없이_매번_원본을_조회한다() {
			assertThat(rates.find("JPY")).isEqualTo("JPY:1");
			assertThat(rates.find("JPY")).isEqualTo("JPY:2");
		}
	}

	@Component
	static class Rates {

		private int calls;

		@Cacheable("rates")
		public String find(String currencyCode) {
			return currencyCode + ":" + ++calls;
		}
	}
}
