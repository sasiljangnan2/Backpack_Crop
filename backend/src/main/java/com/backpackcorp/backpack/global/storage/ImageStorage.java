package com.backpackcorp.backpack.global.storage;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Iterator;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;

// 업로드된 이미지를 저장하고, 앱이 불러올 주소를 만든다.
//   저장 → store(image)가 돌려준 키를 DB에 저장한다. 주소가 아니라 키를 저장해야 저장 위치가 바뀌어도 DB를 고치지 않는다
//   응답 → url(key)로 만든 주소를 내려준다
//   교체·삭제 → delete(key)
// 저장한 파일은 /files/{키}로 토큰 없이 열린다 (application.yaml의 static-path-pattern, SecurityConfig의 PUBLIC_APIS).
// 키가 무작위 UUID라서 주소를 받은 사람만 볼 수 있다.
//
// ponytail: 서버 디스크에 저장한다. 서버가 한 대이고 그 디스크(도커라면 볼륨)가 유지될 때만 맞는다.
//  서버를 여러 대 띄우거나 디스크가 유지되지 않는 환경에 배포하면 S3 같은 외부 저장소로 바꾼다.
//  그때는 이 클래스의 store / url / delete 내부만 바꾸면 된다
@Component
public class ImageStorage {

	// 허용하는 형식(ImageIO 형식 이름 → 저장 확장자). HEIC·WebP·GIF는 받지 않으므로 앱이 JPG나 PNG로 바꿔서 보내야 한다
	private static final Map<String, String> EXTENSIONS = Map.of("jpeg", "jpg", "png", "png");
	// 파일 용량은 작아도 화소 수가 지나치게 큰 이미지를 걸러낸다 (받아서 화면에 펼치는 앱의 메모리를 다 쓴다).
	// 5천만 화소 카메라 원본까지 허용
	private static final long MAX_PIXELS = 50_000_000;

	private final Path root;
	private final String publicBaseUrl;

	public ImageStorage(@Value("${storage.root-path}") String rootPath,
		@Value("${storage.public-base-url}") String publicBaseUrl) {
		this.root = Path.of(rootPath).toAbsolutePath().normalize();
		this.publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
	}

	// 이미지가 아니거나 허용하지 않는 형식이면 INVALID_IMAGE.
	// 파일 크기 제한은 spring.servlet.multipart가 먼저 걸러낸다 (PAYLOAD_TOO_LARGE)
	public String store(MultipartFile image) {
		String key = UUID.randomUUID() + "." + detectExtension(image);
		try (InputStream in = image.getInputStream()) {
			Files.createDirectories(root);
			Files.copy(in, root.resolve(key));
		} catch (IOException e) {
			throw new UncheckedIOException(e);
		}
		return key;
	}

	public String url(String key) {
		return key == null ? null : publicBaseUrl + "/" + key;
	}

	public void delete(String key) {
		if (key == null) {
			return;
		}
		Path target = root.resolve(key).normalize();
		// 키가 저장 폴더 바로 아래의 파일이 아니면 지우지 않는다
		if (!root.equals(target.getParent())) {
			return;
		}
		try {
			Files.deleteIfExists(target);
		} catch (IOException e) {
			throw new UncheckedIOException(e);
		}
	}

	// 파일명과 Content-Type은 보내는 쪽이 마음대로 정할 수 있으므로 믿지 않고, 파일 내용을 읽어 형식을 판별한다
	private static String detectExtension(MultipartFile image) {
		String extension = image == null ? null : readExtension(image);
		if (extension == null) {
			throw new BaseException(ErrorCode.INVALID_IMAGE);
		}
		return extension;
	}

	private static String readExtension(MultipartFile image) {
		try (InputStream in = image.getInputStream();
			ImageInputStream imageIn = ImageIO.createImageInputStream(in)) {
			Iterator<ImageReader> readers = ImageIO.getImageReaders(imageIn);
			if (!readers.hasNext()) {
				return null;
			}
			ImageReader reader = readers.next();
			try {
				reader.setInput(imageIn, true, true);
				// 헤더만 읽는다 (화소 전체를 펼치지 않는다)
				long pixels = (long)reader.getWidth(0) * reader.getHeight(0);
				return pixels > MAX_PIXELS ? null : EXTENSIONS.get(reader.getFormatName().toLowerCase(Locale.ROOT));
			} finally {
				reader.dispose();
			}
		} catch (IOException e) {
			return null;
		}
	}
}
