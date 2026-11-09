package com.backpackcorp.backpack.global.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.HexFormat;

import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

// 비밀번호 대입 공격을 늦춘다. 같은 이메일로 WINDOW 안에 MAX_FAILURES번 틀리면 그 시간 동안 로그인을 막는다.
// 키에는 이메일 원문 대신 해시를 쓴다 (Redis에 개인정보를 남기지 않는다).
// Redis가 응답하지 않으면 막지 않는다 (제한 기능 때문에 로그인 자체가 멈추면 안 된다)
@Slf4j
@Component
@RequiredArgsConstructor
public class LoginAttemptLimiter {

	static final int MAX_FAILURES = 5;
	static final Duration WINDOW = Duration.ofMinutes(15);
	private static final String KEY_PREFIX = "login-fail:";

	private final StringRedisTemplate redis;

	public boolean isBlocked(String email) {
		try {
			String count = redis.opsForValue().get(key(email));
			return count != null && Long.parseLong(count) >= MAX_FAILURES;
		} catch (DataAccessException e) {
			log.warn("로그인 시도 횟수를 확인하지 못했습니다: {}", e.getMessage());
			return false;
		}
	}

	public void recordFailure(String email) {
		try {
			Long count = redis.opsForValue().increment(key(email));
			if (count != null && count == 1) {
				redis.expire(key(email), WINDOW);
			}
		} catch (DataAccessException e) {
			log.warn("로그인 실패를 기록하지 못했습니다: {}", e.getMessage());
		}
	}

	public void reset(String email) {
		try {
			redis.delete(key(email));
		} catch (DataAccessException e) {
			log.warn("로그인 실패 기록을 지우지 못했습니다: {}", e.getMessage());
		}
	}

	private static String key(String email) {
		try {
			byte[] hash = MessageDigest.getInstance("SHA-256").digest(email.getBytes(StandardCharsets.UTF_8));
			return KEY_PREFIX + HexFormat.of().formatHex(hash);
		} catch (NoSuchAlgorithmException e) {
			throw new IllegalStateException(e);
		}
	}
}
