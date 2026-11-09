package com.backpackcorp.backpack.user.service;

import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.global.security.JwtProperties;
import com.backpackcorp.backpack.global.security.LoginAttemptLimiter;
import com.backpackcorp.backpack.global.security.TokenService;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.dto.AuthResponse;
import com.backpackcorp.backpack.user.dto.LoginRequest;
import com.backpackcorp.backpack.user.dto.SignupRequest;
import com.backpackcorp.backpack.user.dto.UserResponse;
import com.backpackcorp.backpack.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

// 가입 · 로그인 · 토큰 재발급 · 로그아웃.
// 액세스 토큰은 30분, 리프레시 토큰은 14일 (application.yaml의 jwt)
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AuthService {

	private static final String TOKEN_TYPE = "Bearer";

	private final UserRepository userRepository;
	private final PasswordEncoder passwordEncoder;
	private final TokenService tokenService;
	private final JwtProperties jwtProperties;
	private final LoginAttemptLimiter loginAttemptLimiter;

	// 없는 이메일로 로그인해도 비밀번호를 검사하는 시간이 같도록 쓰는 해시 (응답 시간으로 가입 여부를 알 수 없게 한다)
	private volatile String dummyHash;

	// 가입하면 바로 로그인한 상태가 된다
	@Transactional
	public AuthResponse signup(SignupRequest request) {
		String email = normalizeEmail(request.email());
		if (userRepository.existsByEmail(email)) {
			throw BaseException.of(ErrorCode.EMAIL_ALREADY_EXISTS, "email", "이미 가입된 이메일이에요.");
		}
		User user = userRepository.save(User.builder()
			.email(email)
			.passwordHash(passwordEncoder.encode(request.password()))
			.name(request.name().trim())
			.build());
		log.info("회원 가입: userId={}", user.getId());
		return issueTokens(user);
	}

	// 실패 사유(이메일 없음 / 비밀번호 틀림 / 탈퇴)는 구분하지 않고 INVALID_CREDENTIALS로 응답한다
	public AuthResponse login(LoginRequest request) {
		String email = normalizeEmail(request.email());
		if (loginAttemptLimiter.isBlocked(email)) {
			throw new BaseException(ErrorCode.TOO_MANY_LOGIN_ATTEMPTS);
		}
		Optional<User> user = userRepository.findByEmail(email).filter(found -> !found.isDeleted());
		String hash = user.map(User::getPasswordHash).orElseGet(this::dummyHash);
		boolean matches = passwordEncoder.matches(request.password(), hash);
		if (user.isEmpty() || !matches) {
			loginAttemptLimiter.recordFailure(email);
			throw new BaseException(ErrorCode.INVALID_CREDENTIALS);
		}
		loginAttemptLimiter.reset(email);
		return issueTokens(user.get());
	}

	// 리프레시 토큰은 한 번 쓰면 짧은 유예 뒤 사라지므로 새 리프레시 토큰을 함께 발급한다
	public AuthResponse reissue(String refreshToken) {
		UUID userId = tokenService.consumeRefreshToken(refreshToken)
			.orElseThrow(() -> new BaseException(ErrorCode.UNAUTHORIZED));
		User user = userRepository.findById(userId)
			.filter(found -> !found.isDeleted())
			.orElseThrow(() -> new BaseException(ErrorCode.UNAUTHORIZED));
		return issueTokens(user);
	}

	public void logout(String refreshToken) {
		tokenService.revokeRefreshToken(refreshToken);
	}

	AuthResponse issueTokens(User user) {
		String accessToken = tokenService.createAccessToken(user.getId(), user.getRole());
		String refreshToken = tokenService.createRefreshToken(user.getId());
		return new AuthResponse(TOKEN_TYPE, accessToken, jwtProperties.accessTokenExpiration().toSeconds(),
			refreshToken, UserResponse.from(user));
	}

	public static String normalizeEmail(String email) {
		return email.trim().toLowerCase(Locale.ROOT);
	}

	private String dummyHash() {
		if (dummyHash == null) {
			dummyHash = passwordEncoder.encode(UUID.randomUUID().toString());
		}
		return dummyHash;
	}
}
