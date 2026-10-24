package com.backpackcorp.backpack.global.exception;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Locale;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.WebApplicationContext;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

@SpringBootTest
@ActiveProfiles("test")
@Import(ValidationMessageLocaleTest.NameController.class)
class ValidationMessageLocaleTest {

	private final Locale original = Locale.getDefault();

	@Autowired
	private WebApplicationContext context;

	@AfterEach
	void tearDown() {
		Locale.setDefault(original);
	}

	// 운영 컨테이너는 영어 로케일이고, 앱이 보내는 Accept-Language도 제각각이다
	@Test
	void 서버_로케일이나_요청_언어와_상관없이_한국어_메시지를_내려준다() throws Exception {
		Locale.setDefault(Locale.ENGLISH);

		MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build()
			.perform(post("/test/names").header(HttpHeaders.ACCEPT_LANGUAGE, "en-US")
				.contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.name").value("공백일 수 없습니다"));
	}

	record NameRequest(@NotBlank String name) {
	}

	// 테스트 클래스 안의 컴포넌트는 스캔되지 않으므로 @Import로 등록한다
	@RestController
	static class NameController {

		@PostMapping("/test/names")
		public void create(@Valid @RequestBody NameRequest request) {
		}
	}
}
