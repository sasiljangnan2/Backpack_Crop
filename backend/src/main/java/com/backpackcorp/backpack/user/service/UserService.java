package com.backpackcorp.backpack.user.service;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.global.security.TokenService;
import com.backpackcorp.backpack.trip.service.TripService;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.dto.AuthResponse;
import com.backpackcorp.backpack.user.dto.NotificationSettingsRequest;
import com.backpackcorp.backpack.user.dto.PasswordChangeRequest;
import com.backpackcorp.backpack.user.dto.UserResponse;
import com.backpackcorp.backpack.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

// 내 정보 · 이름 · 비밀번호 · 알림 설정 · 탈퇴
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

	private final UserRepository userRepository;
	private final PasswordEncoder passwordEncoder;
	private final TokenService tokenService;
	private final AuthService authService;
	private final TripService tripService;
	private final Clock clock;

	public UserResponse getMe(UUID userId) {
		return UserResponse.from(activeUser(userId));
	}

	@Transactional
	public UserResponse changeName(UUID userId, String name) {
		User user = activeUser(userId);
		user.changeName(name.trim());
		return UserResponse.from(user);
	}

	// 다른 기기는 모두 로그아웃되고, 지금 기기는 응답의 새 토큰으로 계속 쓴다
	@Transactional
	public AuthResponse changePassword(UUID userId, PasswordChangeRequest request) {
		User user = activeUser(userId);
		if (!passwordEncoder.matches(request.currentPassword(), user.getPasswordHash())) {
			throw BaseException.of(ErrorCode.INVALID_PASSWORD, "currentPassword", "현재 비밀번호가 맞지 않아요.");
		}
		user.changePasswordHash(passwordEncoder.encode(request.newPassword()));
		tokenService.revokeAllRefreshTokens(userId);
		return authService.issueTokens(user);
	}

	@Transactional
	public UserResponse changeNotificationSettings(UUID userId, NotificationSettingsRequest request) {
		User user = activeUser(userId);
		user.changeNotificationSettings(request.notifySchedule(), request.notifyExpense(), request.notifySettlement());
		return UserResponse.from(user);
	}

	// 회원 행은 지우지 않는다 (지출·정산이 멤버를 통해 이 회원을 가리킨다).
	// 참여 중인 여행에서는 모두 나가고, 방장이던 여행은 다음 멤버에게 넘긴다
	@Transactional
	public void withdraw(UUID userId, String password) {
		User user = activeUser(userId);
		if (!passwordEncoder.matches(password, user.getPasswordHash())) {
			throw BaseException.of(ErrorCode.INVALID_PASSWORD, "password", "비밀번호가 맞지 않아요.");
		}
		tripService.leaveAllTrips(userId, user.getName());
		user.withdraw(Instant.now(clock), "deleted-" + userId + "@withdrawn.invalid",
			passwordEncoder.encode(UUID.randomUUID().toString()));
		tokenService.revokeAllRefreshTokens(userId);
		log.info("회원 탈퇴: userId={}", userId);
	}

	private User activeUser(UUID userId) {
		return userRepository.findById(userId)
			.filter(user -> !user.isDeleted())
			.orElseThrow(() -> new BaseException(ErrorCode.USER_NOT_FOUND));
	}
}
