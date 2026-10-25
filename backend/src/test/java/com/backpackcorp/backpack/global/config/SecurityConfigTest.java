package com.backpackcorp.backpack.global.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.WebApplicationContext;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.global.security.JwtProperties;
import com.backpackcorp.backpack.global.security.TokenService;
import com.backpackcorp.backpack.user.domain.Role;

@SpringBootTest
@ActiveProfiles("test")
@Import(SecurityConfigTest.MeController.class)
class SecurityConfigTest {

	// 토큰이 있어야 하는 경로. 토큰이 없거나 잘못되면 컨트롤러에 닿기 전에 401이 나온다
	private static final String PROTECTED_PATH = "/api/trips";

	@Autowired
	private WebApplicationContext context;
	@Autowired
	private TokenService tokenService;
	@Autowired
	private StringRedisTemplate redis;
	@Autowired
	private JwtProperties jwtProperties;
	@Autowired
	private JwtEncoder jwtEncoder;
	@Autowired
	private JwtDecoder jwtDecoder;

	private MockMvc mockMvc;

	@BeforeEach
	void setUp() {
		mockMvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
	}

	@Test
	void 토큰이_없으면_401을_ErrorResponse_형식으로_응답한다() throws Exception {
		mockMvc.perform(get(PROTECTED_PATH))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
	}

	@Test
	void 공개_목록에_없는_auth_경로는_인증이_필요하다() throws Exception {
		mockMvc.perform(post("/api/auth/logout"))
			.andExpect(status().isUnauthorized());
		mockMvc.perform(get("/api/auth/login"))
			.andExpect(status().isUnauthorized());
	}

	@Test
	void 유효한_토큰이면_컨트롤러가_BackpackUserDetails를_받는다() throws Exception {
		UUID userId = UUID.randomUUID();
		String token = tokenService.createAccessToken(userId, Role.USER);

		mockMvc.perform(get("/test/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
			.andExpect(status().isOk())
			.andExpect(content().string(userId + ":USER"));
	}

	@Test
	void PreAuthorize는_권한이_없으면_403이고_있으면_통과한다() throws Exception {
		String userToken = tokenService.createAccessToken(UUID.randomUUID(), Role.USER);
		String adminToken = tokenService.createAccessToken(UUID.randomUUID(), Role.ADMIN);

		mockMvc.perform(get("/test/admin").header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("FORBIDDEN"));
		mockMvc.perform(get("/test/admin").header(HttpHeaders.AUTHORIZATION, "Bearer " + adminToken))
			.andExpect(status().isOk());
	}

	@Test
	void 다른_키로_서명한_토큰은_401이다() throws Exception {
		SecretKeySpec otherKey = new SecretKeySpec(
			"another-secret-that-is-at-least-32-bytes".getBytes(StandardCharsets.UTF_8), "HmacSHA256");
		TokenService forger =
			new TokenService(NimbusJwtEncoder.withSecretKey(otherKey).build(), redis, jwtProperties);
		String forged = forger.createAccessToken(UUID.randomUUID(), Role.ADMIN);

		mockMvc.perform(get(PROTECTED_PATH).header(HttpHeaders.AUTHORIZATION, "Bearer " + forged))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
	}

	@Test
	void 만료된_토큰은_TOKEN_EXPIRED로_구분해서_응답한다() throws Exception {
		Instant now = Instant.now();
		JwtClaimsSet claims = JwtClaimsSet.builder()
			.subject(UUID.randomUUID().toString())
			.claim(TokenService.ROLE_CLAIM, Role.USER.name())
			.issuedAt(now.minusSeconds(7200))
			.expiresAt(now.minusSeconds(3600))
			.build();
		String expired = jwtEncoder
			.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims))
			.getTokenValue();

		mockMvc.perform(get(PROTECTED_PATH).header(HttpHeaders.AUTHORIZATION, "Bearer " + expired))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("TOKEN_EXPIRED"));
	}

	@Test
	void 서명은_맞지만_role이_없는_값이면_500이_아니라_401이다() throws Exception {
		JwtClaimsSet claims = JwtClaimsSet.builder()
			.subject(UUID.randomUUID().toString())
			.claim(TokenService.ROLE_CLAIM, "GHOST")
			.expiresAt(Instant.now().plusSeconds(60))
			.build();
		String token = jwtEncoder
			.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims))
			.getTokenValue();

		mockMvc.perform(get(PROTECTED_PATH).header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
	}

	@Test
	void 공개_API는_토큰_없이_통과한다() throws Exception {
		mockMvc.perform(post("/api/auth/signup"))
			.andExpect(result -> assertThat(result.getResponse().getStatus()).isNotEqualTo(401));
	}

	@Test
	void 공개_API는_만료되거나_잘못된_토큰이_붙어_있어도_통과한다() throws Exception {
		mockMvc.perform(post("/api/auth/reissue").header(HttpHeaders.AUTHORIZATION, "Bearer expired-or-garbage"))
			.andExpect(result -> assertThat(result.getResponse().getStatus()).isNotEqualTo(401));
	}

	@Test
	void 토큰의_sub와_role이_사용자_ID와_권한이_된다() {
		UUID userId = UUID.randomUUID();
		String token = tokenService.createAccessToken(userId, Role.ADMIN);

		BackpackUserDetails user = BackpackUserDetails.from(jwtDecoder.decode(token));

		assertThat(user.getId()).isEqualTo(userId);
		assertThat(user.getRole()).isEqualTo(Role.ADMIN);
		assertThat(user.getAuthorities()).extracting("authority").containsExactly("ROLE_ADMIN");
	}

	@Test
	void 짧은_시크릿은_거부한다() {
		assertThatThrownBy(() -> new JwtProperties("too-short", Duration.ofMinutes(30), Duration.ofDays(14)))
			.isInstanceOf(IllegalArgumentException.class);
	}

	// 테스트 클래스 안의 컴포넌트는 스캔되지 않으므로 @Import로 등록한다
	@RestController
	static class MeController {

		@GetMapping("/test/me")
		public String me(@AuthenticationPrincipal BackpackUserDetails user) {
			return user.getId() + ":" + user.getRole();
		}

		@PreAuthorize("hasRole('ADMIN')")
		@GetMapping("/test/admin")
		public String admin() {
			return "ok";
		}
	}
}
