package com.backpackcorp.backpack.global.config;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import lombok.extern.slf4j.Slf4j;

// "지금"을 정하는 시계. LocalDate.now()를 직접 부르지 않고 이 빈을 주입받는다.
// 시연 때는 app.demo.now(예: 2026-10-03T05:50:00Z = 도쿄 14:50)로 시각을 고정할 수 있다.
// 토큰 만료 시각은 이 시계를 쓰지 않는다 (시연 중에도 토큰은 실제 시간으로 만료된다)
@Slf4j
@Configuration
public class ClockConfig {

	@Bean
	public Clock clock(@Value("${app.demo.now:}") String demoNow) {
		if (demoNow.isBlank()) {
			return Clock.systemUTC();
		}
		log.warn("시연용 고정 시각을 씁니다: app.demo.now={}", demoNow);
		return Clock.fixed(Instant.parse(demoNow), ZoneOffset.UTC);
	}
}
