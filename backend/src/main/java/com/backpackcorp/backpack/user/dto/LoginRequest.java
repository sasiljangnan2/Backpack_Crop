package com.backpackcorp.backpack.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

// 로그인 요청 본문 { "email": ..., "password": ... }
// 비밀번호 길이는 검사하지 않는다. 규칙이 바뀌어도 예전 비밀번호로 로그인할 수 있어야 한다
public record LoginRequest(
	@NotBlank @Email String email,
	@NotBlank String password
) {
}
