package com.backpackcorp.backpack.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import com.backpackcorp.backpack.support.InMemoryRedis;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;

// 시연 1단계: 로그인 (오류 → 성공)
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class AuthApiTest {

	private static final String PASSWORD = "backpack1234";

	@Autowired
	private WebApplicationContext context;
	@Autowired
	private UserRepository userRepository;
	@MockitoBean
	private StringRedisTemplate redis;

	private MockMvc mockMvc;

	@BeforeEach
	void setUp() {
		InMemoryRedis.install(redis);
		mockMvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
	}

	@Test
	void 가입하면_바로_토큰을_받고_내_정보를_볼_수_있다() throws Exception {
		String body = signup("Minji@Example.com", PASSWORD, " 민지 ")
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.tokenType").value("Bearer"))
			.andExpect(jsonPath("$.accessTokenExpiresIn").value(1800))
			.andExpect(jsonPath("$.refreshToken").isNotEmpty())
			.andExpect(jsonPath("$.user.email").value("minji@example.com"))
			.andExpect(jsonPath("$.user.name").value("민지"))
			.andReturn().getResponse().getContentAsString();
		String access = JsonPath.read(body, "$.accessToken");

		perform(get("/api/users/me"), access, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.email").value("minji@example.com"))
			.andExpect(jsonPath("$.notifyExpense").value(true));
		perform(get("/api/me"), access, null).andExpect(status().isOk());
		// 비밀번호는 해시로만 저장된다
		User saved = userRepository.findByEmail("minji@example.com").orElseThrow();
		assertThat(saved.getPasswordHash()).startsWith("{bcrypt}").doesNotContain(PASSWORD);
	}

	@Test
	void 가입_규칙에_맞지_않으면_400이고_중복_이메일은_409다() throws Exception {
		signup("not-an-email", "short", "")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
			.andExpect(jsonPath("$.details.email").exists())
			.andExpect(jsonPath("$.details.password").exists())
			.andExpect(jsonPath("$.details.name").exists());
		signup("a@b.c", "onlyletters", "가").andExpect(jsonPath("$.details.password").exists());

		signup("dup@b.c", PASSWORD, "가").andExpect(status().isCreated());
		signup("DUP@b.c", PASSWORD, "나")
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("EMAIL_ALREADY_EXISTS"));
	}

	@Test
	void 로그인_실패는_이메일이_없는지_비밀번호가_틀렸는지_구분하지_않는다() throws Exception {
		signup("host@b.c", PASSWORD, "김방장").andExpect(status().isCreated());

		login("host@b.c", "wrong-password1")
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
		login("nobody@b.c", PASSWORD)
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
		login(" HOST@b.c ", PASSWORD)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.user.name").value("김방장"));
	}

	@Test
	void 같은_이메일로_5번_틀리면_잠시_로그인을_막는다() throws Exception {
		signup("host@b.c", PASSWORD, "김방장").andExpect(status().isCreated());
		for (int i = 0; i < 5; i++) {
			login("host@b.c", "wrong-password1").andExpect(status().isUnauthorized());
		}

		login("host@b.c", PASSWORD)
			.andExpect(status().isTooManyRequests())
			.andExpect(jsonPath("$.code").value("TOO_MANY_LOGIN_ATTEMPTS"));
	}

	@Test
	void 재발급하면_새_토큰_한_쌍을_받고_로그아웃한_토큰은_쓸_수_없다() throws Exception {
		String body = signup("host@b.c", PASSWORD, "김방장").andReturn().getResponse().getContentAsString();
		String access = JsonPath.read(body, "$.accessToken");
		String refresh = JsonPath.read(body, "$.refreshToken");

		String reissued = perform(post("/api/auth/reissue"), null, "{\"refreshToken\":\"" + refresh + "\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.accessToken").isNotEmpty())
			.andReturn().getResponse().getContentAsString();
		String newRefresh = JsonPath.read(reissued, "$.refreshToken");
		assertThat(newRefresh).isNotEqualTo(refresh);

		perform(post("/api/auth/logout"), access, "{\"refreshToken\":\"" + newRefresh + "\"}")
			.andExpect(status().isNoContent());
		perform(post("/api/auth/reissue"), null, "{\"refreshToken\":\"" + newRefresh + "\"}")
			.andExpect(status().isUnauthorized());
		perform(post("/api/auth/reissue"), null, "{\"refreshToken\":\"never-issued\"}")
			.andExpect(status().isUnauthorized());
	}

	@Test
	void 비밀번호를_바꾸면_이전_리프레시_토큰은_무효가_되고_새_토큰을_받는다() throws Exception {
		String body = signup("host@b.c", PASSWORD, "김방장").andReturn().getResponse().getContentAsString();
		String access = JsonPath.read(body, "$.accessToken");
		String refresh = JsonPath.read(body, "$.refreshToken");

		perform(patch("/api/users/me/password"), access,
			"{\"currentPassword\":\"wrong-password1\",\"newPassword\":\"newpass1234\"}")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("INVALID_PASSWORD"));
		perform(patch("/api/users/me/password"), access,
			"{\"currentPassword\":\"" + PASSWORD + "\",\"newPassword\":\"newpass1234\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.refreshToken").isNotEmpty());

		perform(post("/api/auth/reissue"), null, "{\"refreshToken\":\"" + refresh + "\"}")
			.andExpect(status().isUnauthorized());
		login("host@b.c", PASSWORD).andExpect(status().isUnauthorized());
		login("host@b.c", "newpass1234").andExpect(status().isOk());
	}

	@Test
	void 이름과_알림_설정을_바꿀_수_있다() throws Exception {
		String access = JsonPath.read(signup("host@b.c", PASSWORD, "김방장").andReturn().getResponse()
			.getContentAsString(), "$.accessToken");

		perform(patch("/api/users/me"), access, "{\"name\":\"박방장\"}")
			.andExpect(jsonPath("$.name").value("박방장"));
		perform(patch("/api/users/me/notification-settings"), access, "{\"notifyExpense\":false}")
			.andExpect(jsonPath("$.notifyExpense").value(false))
			.andExpect(jsonPath("$.notifySchedule").value(true));
	}

	@Test
	void 탈퇴하면_로그인할_수_없고_같은_이메일로_다시_가입할_수_있다() throws Exception {
		String access = JsonPath.read(signup("host@b.c", PASSWORD, "김방장").andReturn().getResponse()
			.getContentAsString(), "$.accessToken");

		perform(delete("/api/users/me"), access, "{\"password\":\"wrong-password1\"}")
			.andExpect(status().isBadRequest());
		perform(delete("/api/users/me"), access, "{\"password\":\"" + PASSWORD + "\"}")
			.andExpect(status().isNoContent());

		login("host@b.c", PASSWORD).andExpect(status().isUnauthorized());
		perform(get("/api/users/me"), access, null).andExpect(status().isNotFound());
		signup("host@b.c", PASSWORD, "새사람").andExpect(status().isCreated());
	}

	@Test
	void 토큰이_없으면_401이다() throws Exception {
		mockMvc.perform(get("/api/users/me"))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
	}

	private ResultActions signup(String email, String password, String name) throws Exception {
		return perform(post("/api/auth/signup"), null,
			"{\"email\":\"%s\",\"password\":\"%s\",\"name\":\"%s\"}".formatted(email, password, name));
	}

	private ResultActions login(String email, String password) throws Exception {
		return perform(post("/api/auth/login"), null,
			"{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, password));
	}

	private ResultActions perform(MockHttpServletRequestBuilder request, String accessToken, String body)
		throws Exception {
		if (accessToken != null) {
			request.header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken);
		}
		if (body != null) {
			request.contentType(MediaType.APPLICATION_JSON).content(body);
		}
		return mockMvc.perform(request);
	}
}
