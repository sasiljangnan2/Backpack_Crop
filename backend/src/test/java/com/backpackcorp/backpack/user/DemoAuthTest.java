package com.backpackcorp.backpack.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.backpackcorp.backpack.support.InMemoryRedis;
import com.jayway.jsonpath.JsonPath;

@SpringBootTest(properties = {
	"JWT_SECRET=demo-test-secret-at-least-32-bytes",
	"REDIS_URL=redis://localhost:6379",
	"exchange-rate.fetch-enabled=false",
	"map.fetch-enabled=false"
})
@ActiveProfiles("demo")
class DemoAuthTest {

	@Autowired
	private WebApplicationContext context;
	@Autowired
	private Environment environment;
	@MockitoBean
	private StringRedisTemplate redis;

	@Test
	void 시연_프로필에서도_가입과_로그인_후_인증이_적용된다() throws Exception {
		InMemoryRedis.install(redis);
		MockMvc mvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
		assertThat(environment.getProperty("spring.datasource.url")).startsWith("jdbc:h2:mem:");
		assertThat(environment.getProperty("spring.flyway.enabled", Boolean.class)).isFalse();
		assertThat(environment.getProperty("spring.h2.console.enabled", Boolean.class)).isFalse();

		mvc.perform(post("/api/auth/signup").contentType(MediaType.APPLICATION_JSON)
			.content("""
				{"email":"demo@example.com","password":"backpack1234","name":"Demo"}
				"""))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.accessToken").isNotEmpty());
		String login = mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
			.content("""
				{"email":"demo@example.com","password":"backpack1234"}
				"""))
			.andExpect(status().isOk())
			.andReturn().getResponse().getContentAsString();
		String access = JsonPath.read(login, "$.accessToken");
		mvc.perform(get("/api/users/me").header("Authorization", "Bearer " + access))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.email").value("demo@example.com"));
		mvc.perform(get("/api/users/me")).andExpect(status().isUnauthorized());
	}
}
