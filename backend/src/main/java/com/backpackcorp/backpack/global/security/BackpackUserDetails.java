package com.backpackcorp.backpack.global.security;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;

import com.backpackcorp.backpack.user.domain.Role;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

// 인증된 사용자. 컨트롤러에서 @AuthenticationPrincipal BackpackUserDetails user 로 받는다.
// 액세스 토큰의 클레임(sub, role)만으로 만들며 요청마다 DB를 조회하지 않는다
@Getter
@RequiredArgsConstructor
public class BackpackUserDetails implements UserDetails {

	private final UUID id;
	private final Role role;

	public static BackpackUserDetails from(Jwt jwt) {
		try {
			return new BackpackUserDetails(UUID.fromString(jwt.getSubject()),
				Role.valueOf(jwt.getClaimAsString(TokenService.ROLE_CLAIM)));
		} catch (IllegalArgumentException | NullPointerException e) {
			// 서명은 유효하지만 클레임이 발급 형식과 다른 토큰(예: 없어진 role)은 500이 아니라 401로 거부한다
			throw new InvalidBearerTokenException("토큰 클레임이 올바르지 않습니다", e);
		}
	}

	// role "USER" → 권한 "ROLE_USER" (hasRole("USER")로 검사)
	@Override
	public Collection<? extends GrantedAuthority> getAuthorities() {
		return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
	}

	// 토큰으로 인증하므로 비밀번호를 들고 다니지 않는다
	@Override
	public String getPassword() {
		return null;
	}

	@Override
	public String getUsername() {
		return id.toString();
	}
}
