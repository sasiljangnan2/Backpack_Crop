package com.backpackcorp.backpack.user.service;

import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.user.dto.UserResponse;
import com.backpackcorp.backpack.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

// 로그인한 회원 본인의 정보 (/api/users/me)
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

	private final UserRepository userRepository;

	// 액세스 토큰은 만료 전까지 유효하므로, 토큰 발급 뒤 탈퇴한 회원도 여기까지 올 수 있다. 그때는 다시 로그인하게 401
	public UserResponse getMe(UUID userId) {
		return userRepository.findByIdAndDeletedAtIsNull(userId)
			.map(UserResponse::from)
			.orElseThrow(() -> new BaseException(ErrorCode.UNAUTHORIZED));
	}
}
