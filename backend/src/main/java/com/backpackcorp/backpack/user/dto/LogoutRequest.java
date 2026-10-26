package com.backpackcorp.backpack.user.dto;

import jakarta.validation.constraints.NotBlank;

// 로그아웃 요청 본문 { "refreshToken": ... }
public record LogoutRequest(@NotBlank String refreshToken) {
}
