package com.backpackcorp.backpack.global.config;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.google.auth.oauth2.ServiceAccountCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;

import lombok.extern.slf4j.Slf4j;

// FCM 푸시 발송 설정. 서비스 계정 키 파일 경로(firebase.credentials-path)가 있을 때만 켜진다.
// 경로가 없으면(로컬·테스트·CI) FirebaseMessaging 빈이 없으므로, 쓰는 쪽은 ObjectProvider<FirebaseMessaging>로
// 주입받아 빈이 없을 때 발송을 건너뛰어야 한다
@Slf4j
@Configuration
public class FirebaseConfig {

	public FirebaseConfig(@Value("${firebase.credentials-path:}") String credentialsPath) {
		if (credentialsPath.isBlank()) {
			log.warn("firebase.credentials-path가 없어 FCM 푸시 발송이 꺼져 있습니다");
		}
	}

	@Bean
	@ConditionalOnExpression("!'${firebase.credentials-path:}'.isBlank()")
	public FirebaseMessaging firebaseMessaging(@Value("${firebase.credentials-path}") String credentialsPath)
		throws IOException {
		try (InputStream credentials = new FileInputStream(credentialsPath)) {
			FirebaseOptions options = FirebaseOptions.builder()
				.setCredentials(ServiceAccountCredentials.fromStream(credentials))
				.build();
			// FirebaseApp은 JVM에 하나만 만들 수 있다. devtools 재시작처럼 이미 있으면 그대로 쓴다
			FirebaseApp app = FirebaseApp.getApps().isEmpty()
				? FirebaseApp.initializeApp(options)
				: FirebaseApp.getInstance();
			return FirebaseMessaging.getInstance(app);
		}
	}
}
