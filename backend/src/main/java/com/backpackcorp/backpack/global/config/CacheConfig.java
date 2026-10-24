package com.backpackcorp.backpack.global.config;

import org.springframework.cache.annotation.CachingConfigurer;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.interceptor.CacheErrorHandler;
import org.springframework.cache.interceptor.LoggingCacheErrorHandler;
import org.springframework.context.annotation.Configuration;

// @Cacheable 등 캐시 애노테이션을 켠다. 저장소는 Redis이고 수명·키 접두사는 application.yaml의 spring.cache.redis 에 있다.
// 캐시에 넣는 값은 Serializable 이어야 한다 (기본 JDK 직렬화)
@Configuration
@EnableCaching
public class CacheConfig implements CachingConfigurer {

	// 캐시는 부가 기능이다. Redis 장애로 캐시 읽기·쓰기가 실패해도 예외를 던지지 않고
	// 경고 로그만 남긴 뒤 원본을 조회하게 한다
	@Override
	public CacheErrorHandler errorHandler() {
		return new LoggingCacheErrorHandler();
	}
}
