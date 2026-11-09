package com.backpackcorp.backpack.user.controller;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.user.dto.AuthResponse;
import com.backpackcorp.backpack.user.dto.NotificationSettingsRequest;
import com.backpackcorp.backpack.user.dto.PasswordChangeRequest;
import com.backpackcorp.backpack.user.dto.UserResponse;
import com.backpackcorp.backpack.user.dto.UserUpdateRequest;
import com.backpackcorp.backpack.user.dto.WithdrawRequest;
import com.backpackcorp.backpack.user.service.UserService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
public class UserController {

	private final UserService userService;

	// /api/me는 역할 분담 문서의 이름. 같은 응답이다
	@GetMapping({"/api/users/me", "/api/me"})
	public UserResponse getMe(@AuthenticationPrincipal BackpackUserDetails user) {
		return userService.getMe(BackpackUserDetails.requireId(user));
	}

	@PatchMapping("/api/users/me")
	public UserResponse changeName(@AuthenticationPrincipal BackpackUserDetails user,
		@Valid @RequestBody UserUpdateRequest request) {
		return userService.changeName(BackpackUserDetails.requireId(user), request.name());
	}

	// 응답의 새 토큰으로 바꿔 저장한다 (다른 기기는 로그아웃된다)
	@PatchMapping("/api/users/me/password")
	public AuthResponse changePassword(@AuthenticationPrincipal BackpackUserDetails user,
		@Valid @RequestBody PasswordChangeRequest request) {
		return userService.changePassword(BackpackUserDetails.requireId(user), request);
	}

	@PatchMapping("/api/users/me/notification-settings")
	public UserResponse changeNotificationSettings(@AuthenticationPrincipal BackpackUserDetails user,
		@RequestBody NotificationSettingsRequest request) {
		return userService.changeNotificationSettings(BackpackUserDetails.requireId(user), request);
	}

	@DeleteMapping("/api/users/me")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void withdraw(@AuthenticationPrincipal BackpackUserDetails user,
		@Valid @RequestBody WithdrawRequest request) {
		userService.withdraw(BackpackUserDetails.requireId(user), request.password());
	}
}
