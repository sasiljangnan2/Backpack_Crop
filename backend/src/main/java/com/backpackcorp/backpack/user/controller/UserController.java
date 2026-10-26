package com.backpackcorp.backpack.user.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.user.dto.UserResponse;
import com.backpackcorp.backpack.user.service.UserService;

import lombok.RequiredArgsConstructor;

// /api/users/** 는 SecurityConfig에서 액세스 토큰이 있어야 들어온다
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

	private final UserService userService;

	// @AuthenticationPrincipal: 스프링 시큐리티가 검증한 액세스 토큰에서 만든 로그인 사용자 (본문은 없다)
	@GetMapping("/me")
	public UserResponse getMe(@AuthenticationPrincipal BackpackUserDetails user) {
		return userService.getMe(user.getId());
	}
}
