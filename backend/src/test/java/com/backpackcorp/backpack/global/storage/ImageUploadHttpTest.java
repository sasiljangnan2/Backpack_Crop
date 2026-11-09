package com.backpackcorp.backpack.global.storage;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.context.annotation.Import;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;
import org.springframework.web.multipart.MultipartFile;

import com.backpackcorp.backpack.global.security.TokenService;
import com.backpackcorp.backpack.user.domain.Role;

// 업로드 크기 제한과 /files/** 서빙은 서블릿 컨테이너가 처리하므로 MockMvc가 아니라 실제 톰캣으로 확인한다
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Import(ImageUploadHttpTest.UploadController.class)
class ImageUploadHttpTest {

	@Value("${local.server.port}")
	private int port;
	@Autowired
	private TokenService tokenService;

	@Test
	void 업로드한_이미지를_토큰_없이_files_경로로_내려받을_수_있다() {
		byte[] png = ImageStorageTest.image("png");

		String key = upload(png).getBody();
		ResponseEntity<byte[]> download = client().get().uri("/files/{key}", key)
			// 앱의 인터셉터가 만료된 토큰을 붙여 보내도 이미지는 열려야 한다
			.header(HttpHeaders.AUTHORIZATION, "Bearer expired-or-garbage")
			.retrieve().toEntity(byte[].class);

		assertThat(download.getBody()).isEqualTo(png);
		assertThat(download.getHeaders().getContentType()).isEqualTo(MediaType.IMAGE_PNG);
		assertThat(download.getHeaders().getCacheControl()).contains("max-age=31536000");
		assertThat(download.getHeaders().getFirst("X-Content-Type-Options")).isEqualTo("nosniff");
	}

	@Test
	void 이미지가_아니면_400_INVALID_IMAGE로_응답한다() {
		ResponseEntity<String> response = upload("not an image".getBytes());

		assertThat(response.getStatusCode().value()).isEqualTo(400);
		assertThat(response.getBody()).contains("\"code\":\"INVALID_IMAGE\"");
	}

	@Test
	void 크기_제한을_넘으면_413_PAYLOAD_TOO_LARGE로_응답한다() {
		// 제한(10MB)을 훌쩍 넘겨도 연결이 끊기지 않고 응답이 와야 한다 (server.tomcat.max-swallow-size)
		ResponseEntity<String> response = upload(new byte[30 * 1024 * 1024]);

		assertThat(response.getStatusCode().value()).isEqualTo(413);
		assertThat(response.getBody()).contains("\"code\":\"PAYLOAD_TOO_LARGE\"");
	}

	private ResponseEntity<String> upload(byte[] content) {
		MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
		body.add("image", new ByteArrayResource(content) {
			@Override
			public String getFilename() {
				return "photo.png";
			}
		});
		// 업로드는 로그인한 사용자만 한다 (내려받기만 토큰 없이 열려 있다)
		return client().post().uri("/test/images")
			.header(HttpHeaders.AUTHORIZATION,
				"Bearer " + tokenService.createAccessToken(UUID.randomUUID(), Role.USER))
			.contentType(MediaType.MULTIPART_FORM_DATA)
			.body(body)
			.exchange((request, response) -> ResponseEntity.status(response.getStatusCode())
				.body(new String(response.getBody().readAllBytes())));
	}

	private RestClient client() {
		return RestClient.create("http://localhost:" + port);
	}

	// 테스트 클래스 안의 컴포넌트는 스캔되지 않으므로 @Import로 등록한다
	@RestController
	static class UploadController {

		@Autowired
		private ImageStorage imageStorage;

		@PostMapping("/test/images")
		public String upload(@RequestPart("image") MultipartFile image) {
			return imageStorage.store(image);
		}
	}
}
