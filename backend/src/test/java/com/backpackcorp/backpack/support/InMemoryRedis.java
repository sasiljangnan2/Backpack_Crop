package com.backpackcorp.backpack.support;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

// 테스트·CI에는 Redis가 없으므로 @MockitoBean StringRedisTemplate에 메모리 맵 동작을 붙인다.
// 토큰 저장(TokenService)과 로그인 제한(LoginAttemptLimiter)이 쓰는 명령만 흉내 낸다
public final class InMemoryRedis {

	private final Map<String, String> data = new HashMap<>();
	private final Map<String, Duration> ttl = new HashMap<>();

	private InMemoryRedis() {
	}

	@SuppressWarnings("unchecked")
	public static InMemoryRedis install(StringRedisTemplate redis) {
		reset(redis);
		InMemoryRedis store = new InMemoryRedis();
		ValueOperations<String, String> values = mock(ValueOperations.class);
		when(redis.opsForValue()).thenReturn(values);
		when(values.get(anyString())).thenAnswer(call -> store.data.get(call.<String>getArgument(0)));
		doAnswer(call -> {
			store.data.put(call.getArgument(0), call.getArgument(1));
			store.ttl.put(call.getArgument(0), call.getArgument(2));
			return null;
		}).when(values).set(anyString(), anyString(), any(Duration.class));
		when(values.increment(anyString())).thenAnswer(call -> Long.parseLong(
			store.data.merge(call.getArgument(0), "1", (old, one) -> String.valueOf(Long.parseLong(old) + 1))));
		when(redis.getExpire(anyString(), eq(TimeUnit.SECONDS))).thenAnswer(call -> {
			String key = call.getArgument(0);
			Duration left = store.ttl.get(key);
			return store.data.containsKey(key) ? (left == null ? -1L : left.toSeconds()) : -2L;
		});
		when(redis.expire(anyString(), any(Duration.class))).thenAnswer(call -> {
			store.ttl.put(call.getArgument(0), call.getArgument(1));
			return true;
		});
		when(redis.delete(anyString())).thenAnswer(call -> {
			store.ttl.remove(call.<String>getArgument(0));
			return store.data.remove(call.<String>getArgument(0)) != null;
		});
		return store;
	}
}
