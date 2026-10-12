package com.backpackcorp.backpack.global.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

import com.backpackcorp.backpack.user.domain.Role;

// Redis 대신 메모리 맵으로 동작을 흉내 낸다 (테스트·CI에는 Redis가 없다)
class TokenServiceTest {

	private static final Duration TTL = Duration.ofDays(14);
	private static final Duration GRACE = Duration.ofSeconds(30);

	private final Map<String, String> redisData = new HashMap<>();
	private final Map<String, Duration> redisTtl = new HashMap<>();
	private TokenService tokenService;

	@BeforeEach
	@SuppressWarnings("unchecked")
	void setUp() {
		StringRedisTemplate redis = mock(StringRedisTemplate.class);
		ValueOperations<String, String> values = mock(ValueOperations.class);
		when(redis.opsForValue()).thenReturn(values);
		when(values.get(anyString())).thenAnswer(call -> redisData.get(call.<String>getArgument(0)));
		doAnswer(call -> {
			redisData.put(call.getArgument(0), call.getArgument(1));
			redisTtl.put(call.getArgument(0), call.getArgument(2));
			return null;
		}).when(values).set(anyString(), anyString(), any(Duration.class));
		when(values.increment(anyString())).thenAnswer(call -> Long.parseLong(
			redisData.merge(call.getArgument(0), "1", (old, one) -> String.valueOf(Long.parseLong(old) + 1))));
		when(redis.getExpire(anyString(), eq(TimeUnit.SECONDS))).thenAnswer(call -> {
			String key = call.getArgument(0);
			return redisData.containsKey(key) ? redisTtl.get(key).toSeconds() : -2L;
		});
		when(redis.expire(anyString(), any(Duration.class))).thenAnswer(call -> {
			redisTtl.put(call.getArgument(0), call.getArgument(1));
			return true;
		});
		when(redis.delete(anyString())).thenAnswer(call -> redisData.remove(call.<String>getArgument(0)) != null);

		JwtProperties properties =
			new JwtProperties("test-only-secret-at-least-32-bytes-long", Duration.ofMinutes(30), TTL);
		tokenService = new TokenService(NimbusJwtEncoder.withSecretKey(properties.secretKey()).build(), redis, properties);
	}

	@Test
	void 액세스_토큰은_JWT이고_리프레시_토큰으로는_쓸_수_없다() {
		String accessToken = tokenService.createAccessToken(UUID.randomUUID(), Role.USER);

		assertThat(accessToken.split("\\.")).hasSize(3);
		assertThat(tokenService.consumeRefreshToken(accessToken)).isEmpty();
		assertThat(redisData).isEmpty();
	}

	@Test
	void 리프레시_토큰을_쓰면_수명이_유예_시간으로_줄고_그_안에는_다시_쓸_수_있다() {
		UUID userId = UUID.randomUUID();
		String token = tokenService.createRefreshToken(userId);
		assertThat(redisTtl.values()).containsExactly(TTL);

		assertThat(tokenService.consumeRefreshToken(token)).contains(userId);
		assertThat(redisTtl.values()).containsExactly(GRACE);

		// 재발급 응답을 못 받아 같은 토큰으로 다시 요청한 경우
		assertThat(tokenService.consumeRefreshToken(token)).contains(userId);
	}

	@Test
	void 유예_중인_토큰을_다시_써도_수명이_늘어나지_않는다() {
		String token = tokenService.createRefreshToken(UUID.randomUUID());
		tokenService.consumeRefreshToken(token);
		String key = redisTtl.keySet().iterator().next();
		redisTtl.put(key, Duration.ofSeconds(5)); // 유예 시간이 5초 남은 상태

		tokenService.consumeRefreshToken(token);

		assertThat(redisTtl.get(key)).isEqualTo(Duration.ofSeconds(5));
	}

	@Test
	void 발급한_적_없는_리프레시_토큰은_거부한다() {
		tokenService.createRefreshToken(UUID.randomUUID());

		assertThat(tokenService.consumeRefreshToken("never-issued")).isEmpty();
	}

	@Test
	void 폐기한_리프레시_토큰은_쓸_수_없다() {
		String token = tokenService.createRefreshToken(UUID.randomUUID());

		tokenService.revokeRefreshToken(token);

		assertThat(tokenService.consumeRefreshToken(token)).isEmpty();
	}

	@Test
	void 전체_폐기하면_그_사용자의_이전_토큰만_무효가_되고_새로_발급한_토큰은_유효하다() {
		UUID userId = UUID.randomUUID();
		UUID otherUserId = UUID.randomUUID();
		String phone = tokenService.createRefreshToken(userId);
		String tablet = tokenService.createRefreshToken(userId);
		String otherUsers = tokenService.createRefreshToken(otherUserId);

		tokenService.revokeAllRefreshTokens(userId);
		String afterRevoke = tokenService.createRefreshToken(userId);

		assertThat(tokenService.consumeRefreshToken(phone)).isEmpty();
		assertThat(tokenService.consumeRefreshToken(tablet)).isEmpty();
		assertThat(tokenService.consumeRefreshToken(otherUsers)).contains(otherUserId);
		assertThat(tokenService.consumeRefreshToken(afterRevoke)).contains(userId);
	}

	@Test
	void 리프레시_토큰_원문은_Redis에_남지_않는다() {
		String token = tokenService.createRefreshToken(UUID.randomUUID());

		assertThat(redisData.keySet()).singleElement().asString()
			.startsWith("refresh-token:")
			.doesNotContain(token);
	}

	@Test
	void 리프레시_토큰은_매번_다르다() {
		UUID userId = UUID.randomUUID();

		assertThat(tokenService.createRefreshToken(userId)).isNotEqualTo(tokenService.createRefreshToken(userId));
	}
}
