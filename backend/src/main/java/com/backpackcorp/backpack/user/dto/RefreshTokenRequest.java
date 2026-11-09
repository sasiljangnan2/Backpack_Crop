package com.backpackcorp.backpack.user.dto;

import jakarta.validation.constraints.NotBlank;

// 재발급 · 로그아웃
public record RefreshTokenRequest(
	@NotBlank(message = "리프레시 토큰이 필요해요.")
	String refreshToken
) {
}
