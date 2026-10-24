package com.backpackcorp.backpack.user.dto;

import java.util.UUID;

import com.backpackcorp.backpack.user.domain.User;

// 회원가입 응답. 엔티티(User)를 그대로 내보내면 passwordHash까지 나가므로 필요한 필드만 담는다
public record SignupResponse(UUID id, String email, String name) {

	public static SignupResponse from(User user) {
		return new SignupResponse(user.getId(), user.getEmail(), user.getName());
	}
}
