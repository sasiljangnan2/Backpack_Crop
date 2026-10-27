package com.backpackcorp.backpack.user.dto;

// 로그인 · 토큰 재발급 응답 { "accessToken": ..., "refreshToken": ... }
// accessToken은 API 호출마다 Authorization 헤더에, refreshToken은 재발급할 때만 쓴다
public record TokenResponse(String accessToken, String refreshToken) {
}
