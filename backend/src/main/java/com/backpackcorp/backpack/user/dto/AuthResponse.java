package com.backpackcorp.backpack.user.dto;

// 로그인 · 가입 · 재발급 · 비밀번호 변경 응답.
// 리프레시 토큰은 한 번 쓰면 30초 뒤 무효가 되므로 앱은 받은 새 토큰으로 꼭 바꿔 저장한다
public record AuthResponse(
	String tokenType,
	String accessToken,
	long accessTokenExpiresIn,
	String refreshToken,
	UserResponse user
) {
}
