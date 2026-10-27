package com.backpackcorp.backpack.user.dto;

import jakarta.validation.constraints.NotBlank;

// 토큰 재발급 요청 본문 { "refreshToken": ... }. 응답은 로그인과 같은 TokenResponse
public record ReissueRequest(@NotBlank String refreshToken) {
}
