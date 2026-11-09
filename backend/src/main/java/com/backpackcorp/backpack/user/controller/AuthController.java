package com.backpackcorp.backpack.user.controller;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.user.dto.AuthResponse;
import com.backpackcorp.backpack.user.dto.LoginRequest;
import com.backpackcorp.backpack.user.dto.RefreshTokenRequest;
import com.backpackcorp.backpack.user.dto.SignupRequest;
import com.backpackcorp.backpack.user.service.AuthService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

// signup · login · reissue는 토큰 없이 연다 (SecurityConfig의 PUBLIC_APIS). logout은 로그인한 상태에서만
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/auth")
public class AuthController {

	private final AuthService authService;

	// BP-AU-003
	@PostMapping("/signup")
	@ResponseStatus(HttpStatus.CREATED)
	public AuthResponse signup(@Valid @RequestBody SignupRequest request) {
		return authService.signup(request);
	}

	// BP-AU-002
	@PostMapping("/login")
	public AuthResponse login(@Valid @RequestBody LoginRequest request) {
		return authService.login(request);
	}

	@PostMapping("/reissue")
	public AuthResponse reissue(@Valid @RequestBody RefreshTokenRequest request) {
		return authService.reissue(request.refreshToken());
	}

	@PostMapping("/logout")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void logout(@Valid @RequestBody RefreshTokenRequest request) {
		authService.logout(request.refreshToken());
	}
}
