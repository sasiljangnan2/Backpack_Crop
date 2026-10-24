package com.backpackcorp.backpack.global.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPairGenerator;
import java.util.Base64;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;

class FirebaseConfigTest {

	@AfterEach
	void tearDown() {
		FirebaseApp.getApps().forEach(FirebaseApp::delete);
	}

	@Test
	void 서비스_계정_키_파일로_FirebaseMessaging을_만들고_두_번_불러도_재사용한다(@TempDir Path dir) throws Exception {
		String path = fakeServiceAccountKey(dir).toString();
		FirebaseConfig config = new FirebaseConfig(path);

		FirebaseMessaging first = config.firebaseMessaging(path);
		FirebaseMessaging second = config.firebaseMessaging(path);

		assertThat(first).isNotNull();
		assertThat(second).isSameAs(first);
		assertThat(FirebaseApp.getApps()).hasSize(1);
	}

	// 형식만 맞는 가짜 키. 초기화는 네트워크를 타지 않으므로 실제 Firebase 프로젝트가 없어도 된다
	private Path fakeServiceAccountKey(Path dir) throws Exception {
		KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
		generator.initialize(2048);
		String privateKey = Base64.getEncoder().encodeToString(generator.generateKeyPair().getPrivate().getEncoded());
		String json = """
			{
			  "type": "service_account",
			  "project_id": "backpack-test",
			  "private_key_id": "test-key-id",
			  "private_key": "-----BEGIN PRIVATE KEY-----\\n%s\\n-----END PRIVATE KEY-----\\n",
			  "client_email": "test@backpack-test.iam.gserviceaccount.com",
			  "client_id": "1234567890"
			}
			""".formatted(privateKey);
		return Files.writeString(dir.resolve("fake-firebase-adminsdk.json"), json);
	}
}
