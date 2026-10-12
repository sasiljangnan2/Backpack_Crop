package com.backpackcorp.backpack.global.config;

import java.time.Instant;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.web.servlet.HandlerExceptionResolver;

import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.global.security.JwtProperties;

import jakarta.servlet.DispatcherType;

// @EnableMethodSecurity: @PreAuthorize("hasRole('ADMIN')") 같은 메서드 단위 권한 검사를 켠다
@Configuration
@EnableMethodSecurity
@EnableConfigurationProperties(JwtProperties.class)
public class SecurityConfig {

	// 토큰 없이 여는 경로(인증 API, 저장된 이미지). 이 경로에서는 Authorization 헤더도 읽지 않는다 (bearerTokenResolver 참고).
	// 지금은 개발용 permitAll이라 다른 경로도 토큰 없이 열려 있다
	private static final PathPatternRequestMatcher.Builder PATH = PathPatternRequestMatcher.withDefaults();
	private static final RequestMatcher PUBLIC_APIS = new OrRequestMatcher(
		PATH.matcher(HttpMethod.POST, "/api/auth/signup"),
		PATH.matcher(HttpMethod.POST, "/api/auth/login"),
		PATH.matcher(HttpMethod.POST, "/api/auth/reissue"),
		// ImageStorage가 저장한 이미지. 앱의 이미지 위젯은 토큰 없이 주소만으로 불러온다
		PATH.matcher(HttpMethod.GET, "/files/**"));

	@Bean
	public SecurityFilterChain securityFilterChain(HttpSecurity http,
		BearerTokenResolver bearerTokenResolver,
		@Qualifier("handlerExceptionResolver") HandlerExceptionResolver exceptionResolver) throws Exception {
		// 필터 단계의 401/403도 GlobalExceptionHandler로 넘겨 ErrorResponse 형식으로 응답한다
		AuthenticationEntryPoint entryPoint =
			(request, response, e) -> exceptionResolver.resolveException(request, response, null, e);
		AccessDeniedHandler accessDeniedHandler =
			(request, response, e) -> exceptionResolver.resolveException(request, response, null, e);

		return http
			// 토큰을 쿠키가 아닌 Authorization 헤더로 받으므로 CSRF 보호가 필요 없다
			.csrf(AbstractHttpConfigurer::disable)
			.httpBasic(AbstractHttpConfigurer::disable)
			// TODO(로그인·로그아웃): Spring Security 기본 formLogin / logout으로 구현할 예정. 그때까지 꺼 둔다.
			//  - UserDetailsService 빈이 있어야 한다 (없으면 로그인이 항상 실패)
			//  - 세션을 쓰지 않으므로 로그인 성공 시 리다이렉트 대신 토큰을 응답해야 한다
			//  - 로그인 URL은 PUBLIC_APIS와 맞춘다
			.formLogin(AbstractHttpConfigurer::disable)
			.logout(AbstractHttpConfigurer::disable)
			.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
			.authorizeHttpRequests(auth -> auth
				// 컨테이너가 /error로 넘긴 오류(잘못된 URL의 400 등)가 401로 가려지지 않게 한다
				.dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
				.requestMatchers(PUBLIC_APIS).permitAll()
				// TODO(개발용): 로그인이 구현되기 전까지 토큰 없이도 모든 요청을 허용한다.
				//  운영 배포 전에 .anyRequest().authenticated() 로 되돌리고
				//  SecurityConfigTest의 @Disabled 테스트를 다시 켤 것
				.anyRequest().permitAll())
			// Authorization: Bearer <액세스 토큰> 을 검증해 인증 정보로 바꾼다
			.oauth2ResourceServer(oauth2 -> oauth2
				.bearerTokenResolver(bearerTokenResolver)
				.jwt(jwt -> jwt.jwtAuthenticationConverter(SecurityConfig::toAuthentication))
				.authenticationEntryPoint(entryPoint)
				.accessDeniedHandler(accessDeniedHandler))
			.exceptionHandling(handling -> handling
				.authenticationEntryPoint(entryPoint)
				.accessDeniedHandler(accessDeniedHandler))
			.build();
	}

	// 공개 경로(PUBLIC_APIS)에서는 Authorization 헤더를 읽지 않는다.
	// 만료된 액세스 토큰이 붙은 로그인·재발급·이미지 요청이 처리되기도 전에 401로 끊기는 것을 막는다
	@Bean
	public BearerTokenResolver bearerTokenResolver() {
		DefaultBearerTokenResolver headerResolver = new DefaultBearerTokenResolver();
		return request -> PUBLIC_APIS.matches(request) ? null : headerResolver.resolve(request);
	}

	@Bean
	public JwtDecoder jwtDecoder(JwtProperties properties) {
		NimbusJwtDecoder decoder =
			NimbusJwtDecoder.withSecretKey(properties.secretKey()).macAlgorithm(MacAlgorithm.HS256).build();
		decoder.setJwtValidator(
			new DelegatingOAuth2TokenValidator<>(SecurityConfig::rejectExpired, JwtValidators.createDefault()));
		return decoder;
	}

	// 만료를 위조·형식 오류와 구분할 수 있게 전용 오류 코드를 남긴다.
	// GlobalExceptionHandler가 이 코드를 보고 UNAUTHORIZED 대신 TOKEN_EXPIRED로 응답한다
	private static OAuth2TokenValidatorResult rejectExpired(Jwt jwt) {
		boolean expired = jwt.getExpiresAt() != null && Instant.now().isAfter(jwt.getExpiresAt());
		return expired
			? OAuth2TokenValidatorResult.failure(new OAuth2Error(ErrorCode.TOKEN_EXPIRED.name()))
			: OAuth2TokenValidatorResult.success();
	}

	@Bean
	public JwtEncoder jwtEncoder(JwtProperties properties) {
		return NimbusJwtEncoder.withSecretKey(properties.secretKey()).algorithm(MacAlgorithm.HS256).build();
	}

	// 검증된 토큰을 인증 정보로 바꾼다. 인증 주체(principal)가 BackpackUserDetails라서
	// 컨트롤러에서 @AuthenticationPrincipal BackpackUserDetails 로 받을 수 있다
	private static AbstractAuthenticationToken toAuthentication(Jwt jwt) {
		BackpackUserDetails user = BackpackUserDetails.from(jwt);
		return UsernamePasswordAuthenticationToken.authenticated(user, jwt, user.getAuthorities());
	}

	// 저장 형식이 "{bcrypt}..." 라서 나중에 알고리즘을 바꿔도 기존 해시를 검증할 수 있다
	@Bean
	public PasswordEncoder passwordEncoder() {
		return PasswordEncoderFactories.createDelegatingPasswordEncoder();
	}
}
