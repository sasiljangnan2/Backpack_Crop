package com.backpackcorp.backpack.user.service;

import java.util.UUID;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.global.security.TokenService;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.dto.LoginRequest;
import com.backpackcorp.backpack.user.dto.LogoutRequest;
import com.backpackcorp.backpack.user.dto.ReissueRequest;
import com.backpackcorp.backpack.user.dto.SignupRequest;
import com.backpackcorp.backpack.user.dto.SignupResponse;
import com.backpackcorp.backpack.user.dto.TokenResponse;
import com.backpackcorp.backpack.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

// 회원가입 · 로그인 · 토큰 재발급 · 로그아웃.
// final 필드는 @RequiredArgsConstructor가 만든 생성자로 스프링이 주입한다 (new로 만들지 않는다)
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AuthService {

	private final UserRepository userRepository;
	// SecurityConfig에 등록된 빈. 저장 형식은 "{bcrypt}..."
	private final PasswordEncoder passwordEncoder;
	// 액세스 토큰은 JWT, 리프레시 토큰은 Redis에 저장된다 (global/security)
	private final TokenService tokenService;

	// DB에 쓰는 메서드라 readOnly를 풀어 준다
	@Transactional
	public SignupResponse signup(SignupRequest request) {
		// 실패는 예외로 끝낸다. GlobalExceptionHandler가 409 ErrorResponse로 바꿔 응답한다
		if (userRepository.existsByEmail(request.email())) {
			throw new BaseException(ErrorCode.CONFLICT);
		}
		// 비밀번호 원문은 저장하지 않는다. 로그인 때는 passwordEncoder.matches()로 비교한다
		User user = User.builder()
			.email(request.email())
			.passwordHash(passwordEncoder.encode(request.password()))
			.name(request.name())
			.build();
		return SignupResponse.from(userRepository.save(user));
	}

	// MySQL에 쓰는 게 없으므로 클래스의 readOnly = true를 그대로 쓴다
	public TokenResponse login(LoginRequest request) {
		User user = userRepository.findByEmailAndDeletedAtIsNull(request.email())
			.orElseThrow(() -> new BaseException(ErrorCode.UNAUTHORIZED));

		// 저장된 값은 암호문이라 equals가 아니라 matches로 비교한다.
		// 이메일이 없을 때와 같은 에러를 던져, 어떤 이메일이 가입돼 있는지 알려 주지 않는다
		if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
			throw new BaseException(ErrorCode.UNAUTHORIZED);
		}

		return issueTokens(user);
	}

	// 쓴 리프레시 토큰은 30초 뒤 사라지므로, 앱은 응답의 새 리프레시 토큰으로 바꿔 저장해야 한다
	public TokenResponse reissue(ReissueRequest request) {
		UUID userId = tokenService.consumeRefreshToken(request.refreshToken())
			.orElseThrow(() -> new BaseException(ErrorCode.UNAUTHORIZED));
		// 새 액세스 토큰에 role을 넣어야 해서 ID만으로는 부족하다. 그 사이 탈퇴했으면 401
		User user = userRepository.findByIdAndDeletedAtIsNull(userId)
			.orElseThrow(() -> new BaseException(ErrorCode.UNAUTHORIZED));
		return issueTokens(user);
	}

	// 리프레시 토큰만 즉시 폐기한다. 액세스 토큰은 서버에 저장하지 않아 회수할 수 없으므로 앱이 지운다
	public void logout(LogoutRequest request) {
		tokenService.revokeRefreshToken(request.refreshToken());
	}

	// 로그인과 재발급이 같은 형식으로 토큰 2장을 내려준다
	private TokenResponse issueTokens(User user) {
		return new TokenResponse(
			tokenService.createAccessToken(user.getId(), user.getRole()),
			tokenService.createRefreshToken(user.getId()));
	}
}
