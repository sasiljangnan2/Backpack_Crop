package com.backpackcorp.backpack.user.controller;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.user.dto.LoginRequest;
import com.backpackcorp.backpack.user.dto.SignupRequest;
import com.backpackcorp.backpack.user.dto.SignupResponse;
import com.backpackcorp.backpack.user.dto.TokenResponse;
import com.backpackcorp.backpack.user.service.AuthService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

// /api/auth/signup · login · reissue 는 SecurityConfig의 PUBLIC_APIS라 토큰 없이 부를 수 있다.
// Controller는 요청을 받아 Service에 넘기고 성공 응답만 만든다. 실패 응답은 GlobalExceptionHandler가 만든다
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

	private final AuthService authService;

	// @RequestBody: JSON 본문 → SignupRequest, @Valid: 그 안의 검증 어노테이션 실행
	@PostMapping("/signup")
	@ResponseStatus(HttpStatus.CREATED)
	public SignupResponse signup(@Valid @RequestBody SignupRequest request) {
		return authService.signup(request);
	}

	// 상태 코드를 따로 적지 않으면 200 OK로 나간다
	@PostMapping("/login")
	public TokenResponse login(@Valid @RequestBody LoginRequest request) {
		return authService.login(request);
	}
}
