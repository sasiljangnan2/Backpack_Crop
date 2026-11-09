package com.backpackcorp.backpack.global.config;

import java.time.Duration;

import org.springframework.boot.cache.autoconfigure.RedisCacheManagerBuilderCustomizer;
import org.springframework.cache.annotation.CachingConfigurer;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.interceptor.CacheErrorHandler;
import org.springframework.cache.interceptor.LoggingCacheErrorHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;

// @Cacheable 등 캐시 애노테이션을 켠다. 저장소는 Redis이고 수명·키 접두사는 application.yaml의 spring.cache.redis 에 있다.
// 캐시에 넣는 값은 Serializable 이어야 한다 (기본 JDK 직렬화)
@Configuration
@EnableCaching
public class CacheConfig implements CachingConfigurer {

	// 장소 검색 · 이동 시간은 잘 바뀌지 않고, 공용 지도 서버에 같은 요청을 다시 보내지 않으려고 오래 둔다 (OsmClient)
	@Bean
	public RedisCacheManagerBuilderCustomizer mapCacheTtl() {
		// 값은 이 앱의 클래스 로더로 읽는다. 기본 로더를 쓰면 devtools로 재시작한 서버(dev)에서 캐시 값을 꺼낼 때
		// 같은 이름의 다른 클래스로 보여 ClassCastException이 난다
		RedisCacheConfiguration week = RedisCacheConfiguration.defaultCacheConfig(getClass().getClassLoader())
			.prefixCacheNameWith("backpack:cache:")
			.entryTtl(Duration.ofDays(7));
		return builder -> builder
			.withCacheConfiguration("place-search", week)
			.withCacheConfiguration("place-reverse", week)
			.withCacheConfiguration("travel", week)
			// AI 일정 재구성 추천안 (적용할 때 다시 꺼낸다)
			.withCacheConfiguration("replan", week.entryTtl(Duration.ofMinutes(30)));
	}

	// 캐시는 부가 기능이다. Redis 장애로 캐시 읽기·쓰기가 실패해도 예외를 던지지 않고
	// 경고 로그만 남긴 뒤 원본을 조회하게 한다
	@Override
	public CacheErrorHandler errorHandler() {
		return new LoggingCacheErrorHandler();
	}
}
