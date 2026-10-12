package com.backpackcorp.backpack.global.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Component;

import com.backpackcorp.backpack.user.domain.Role;

import lombok.RequiredArgsConstructor;

// 액세스 토큰과 리프레시 토큰의 발급·검증·폐기를 한곳에서 다룬다.
//   로그인          → createAccessToken + createRefreshToken
//   재발급          → consumeRefreshToken 으로 사용자 ID를 얻고, 두 토큰을 새로 발급한다
//   로그아웃        → revokeRefreshToken
//   탈퇴·비밀번호 변경 → revokeAllRefreshTokens (모든 기기 로그아웃)
//
// 액세스 토큰: 서명된 JWT. 서버에 저장하지 않으므로 만료 전에는 폐기할 수 없다.
//   요청마다 하는 검증은 여기가 아니라 Spring Security 필터가 SecurityConfig의 JwtDecoder로 처리한다.
// 리프레시 토큰: 서명 없는 무작위 문자열. Redis에 있는 것만 유효한 화이트리스트 방식이다.
//   JWT가 아니므로 액세스 토큰 자리에 넣어도 통과하지 않는다
@Component
@RequiredArgsConstructor
public class TokenService {

	public static final String ROLE_CLAIM = "role";

	// 값은 "{사용자 ID}:{발급 시점의 세대}"
	private static final String REFRESH_TOKEN_KEY_PREFIX = "refresh-token:";
	// 사용자별 세대 번호. revokeAllRefreshTokens가 1 올리면 이전 세대 토큰은 전부 무효가 된다.
	// 만료 시간을 두지 않는다: 키가 사라지면 세대가 0으로 돌아가, 0세대 때 폐기한 토큰이 다시 유효해진다
	private static final String GENERATION_KEY_PREFIX = "refresh-token-generation:";
	// 재발급 응답을 못 받았거나 재발급을 동시에 두 번 보낸 앱이 로그아웃되지 않도록,
	// 한 번 쓴 토큰도 이 시간 동안은 다시 받아 준다
	private static final Duration REUSE_GRACE = Duration.ofSeconds(30);
	private static final SecureRandom RANDOM = new SecureRandom();

	private final JwtEncoder jwtEncoder;
	private final StringRedisTemplate redis;
	private final JwtProperties properties;

	public String createAccessToken(UUID userId, Role role) {
		Instant now = Instant.now();
		JwtClaimsSet claims = JwtClaimsSet.builder()
			.subject(userId.toString())
			.claim(ROLE_CLAIM, role.name())
			.issuedAt(now)
			.expiresAt(now.plus(properties.accessTokenExpiration()))
			.build();
		JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
		return jwtEncoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
	}

	public String createRefreshToken(UUID userId) {
		byte[] bytes = new byte[32];
		RANDOM.nextBytes(bytes);
		String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
		String value = userId + ":" + generation(userId);
		redis.opsForValue().set(refreshTokenKey(token), value, properties.refreshTokenExpiration());
		return token;
	}

	// 유효하면 사용자 ID를 돌려준다. 토큰은 처음 쓰인 때부터 유예 시간(REUSE_GRACE) 뒤에 사라지므로,
	// 호출한 쪽은 새 리프레시 토큰을 함께 발급해야 한다
	public Optional<UUID> consumeRefreshToken(String token) {
		String key = refreshTokenKey(token);
		String value = redis.opsForValue().get(key);
		if (value == null) {
			return Optional.empty();
		}
		String[] parts = value.split(":");
		UUID userId = UUID.fromString(parts[0]);
		if (Long.parseLong(parts[1]) != generation(userId)) {
			redis.delete(key);
			return Optional.empty();
		}
		// 이미 유예 중인 토큰은 수명을 다시 늘리지 않는다 (반복 사용으로 무한히 살려 두는 것을 막는다)
		Long secondsLeft = redis.getExpire(key, TimeUnit.SECONDS);
		if (secondsLeft == null || secondsLeft < 0 || secondsLeft > REUSE_GRACE.toSeconds()) {
			redis.expire(key, REUSE_GRACE);
		}
		return Optional.of(userId);
	}

	// 유예 없이 즉시 폐기한다
	public void revokeRefreshToken(String token) {
		redis.delete(refreshTokenKey(token));
	}

	// 이 사용자가 지금까지 발급받은 리프레시 토큰을 전부 무효로 만든다.
	// 이미 발급된 액세스 토큰은 만료될 때까지 유효하다
	public void revokeAllRefreshTokens(UUID userId) {
		redis.opsForValue().increment(GENERATION_KEY_PREFIX + userId);
	}

	private long generation(UUID userId) {
		String generation = redis.opsForValue().get(GENERATION_KEY_PREFIX + userId);
		return generation == null ? 0 : Long.parseLong(generation);
	}

	// Redis가 유출돼도 토큰을 그대로 쓸 수 없도록 원문 대신 SHA-256 해시를 키로 쓴다
	private static String refreshTokenKey(String token) {
		try {
			byte[] hash = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
			return REFRESH_TOKEN_KEY_PREFIX + HexFormat.of().formatHex(hash);
		} catch (NoSuchAlgorithmException e) {
			throw new IllegalStateException(e);
		}
	}
}
