package com.backpackcorp.backpack.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

// 회원가입 요청 본문 { "email": ..., "password": ..., "name": ... }
// 검증 어노테이션은 Controller의 @Valid가 실행한다. 어기면 Service까지 가지 않고 400 VALIDATION_ERROR로 응답한다
public record SignupRequest(
	@NotBlank @Email @Size(max = 255) String email,
	// 비밀번호 규칙은 API 문서에 아직 미정이라 8~64자로 둔다. 팀에서 정하면 여기만 고친다
	@NotBlank @Size(min = 8, max = 64) String password,
	@NotBlank @Size(max = 20) String name
) {
}
