package com.backpackcorp.backpack.global.security;

import java.nio.charset.StandardCharsets;
import java.time.Duration;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("jwt")
public record JwtProperties(String secret, Duration accessTokenExpiration, Duration refreshTokenExpiration) {

	// 짧은 키로 서명하는 일이 없도록 기동 시점에 막는다
	public JwtProperties {
		if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32) {
			throw new IllegalArgumentException("jwt.secret은 32바이트 이상이어야 합니다 (HS256)");
		}
		if (accessTokenExpiration == null || !accessTokenExpiration.isPositive()) {
			throw new IllegalArgumentException("jwt.access-token-expiration은 0보다 커야 합니다");
		}
		if (refreshTokenExpiration == null || !refreshTokenExpiration.isPositive()) {
			throw new IllegalArgumentException("jwt.refresh-token-expiration은 0보다 커야 합니다");
		}
	}

	public SecretKey secretKey() {
		return new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
	}
}
