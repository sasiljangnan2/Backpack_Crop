package com.backpackcorp.backpack.global.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;

class ImageStorageTest {

	@TempDir
	Path dir;

	private Path root;
	private ImageStorage imageStorage;

	@BeforeEach
	void setUp() {
		root = dir.resolve("storage");
		imageStorage = new ImageStorage(root.toString(), "https://cdn.example.com/files/");
	}

	@Test
	void 저장하면_키를_돌려주고_파일이_그대로_남는다() throws IOException {
		byte[] png = image("png");

		String key = imageStorage.store(file("photo.png", png));

		assertThat(key).endsWith(".png");
		assertThat(Files.readAllBytes(root.resolve(key))).isEqualTo(png);
		assertThat(imageStorage.url(key)).isEqualTo("https://cdn.example.com/files/" + key);
	}

	@Test
	void 확장자는_파일명이_아니라_실제_내용으로_정한다() {
		String key = imageStorage.store(file("../../evil.jsp", image("jpg")));

		assertThat(key).matches("[0-9a-f-]{36}\\.jpg");
	}

	@Test
	void 이미지가_아니거나_허용하지_않는_형식이면_거부하고_파일을_남기지_않는다() {
		byte[] truncatedPng = Arrays.copyOf(image("png"), 20);

		assertInvalid(file("fake.png", "<script>alert(1)</script>".getBytes(StandardCharsets.UTF_8)));
		assertInvalid(file("animation.gif", image("gif")));
		assertInvalid(file("broken.png", truncatedPng));
		assertInvalid(file("empty.png", new byte[0]));
		assertInvalid(null);
		assertThat(root).doesNotExist();
	}

	@Test
	void 삭제하면_파일이_사라지고_없는_키나_null은_무시한다() {
		String key = imageStorage.store(file("photo.png", image("png")));

		imageStorage.delete(key);
		imageStorage.delete(key);
		imageStorage.delete(null);

		assertThat(root.resolve(key)).doesNotExist();
		assertThat(imageStorage.url(null)).isNull();
	}

	@Test
	void 저장_폴더_밖을_가리키는_키로는_지우지_않는다() throws IOException {
		Path outside = Files.writeString(dir.resolve("outside.txt"), "keep");
		imageStorage.store(file("photo.png", image("png")));

		imageStorage.delete("../outside.txt");
		imageStorage.delete(outside.toString());

		assertThat(outside).exists();
	}

	private void assertInvalid(MockMultipartFile file) {
		assertThatThrownBy(() -> imageStorage.store(file))
			.isInstanceOfSatisfying(BaseException.class,
				e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_IMAGE));
	}

	// 일부러 Content-Type을 틀리게 준다: 클라이언트가 보낸 값은 믿지 않는다
	private static MockMultipartFile file(String filename, byte[] content) {
		return new MockMultipartFile("image", filename, "text/plain", content);
	}

	static byte[] image(String format) {
		try {
			ByteArrayOutputStream out = new ByteArrayOutputStream();
			ImageIO.write(new BufferedImage(4, 4, BufferedImage.TYPE_INT_RGB), format, out);
			return out.toByteArray();
		} catch (IOException e) {
			throw new IllegalStateException(e);
		}
	}
}
