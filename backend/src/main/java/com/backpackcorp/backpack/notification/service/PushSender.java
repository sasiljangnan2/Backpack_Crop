package com.backpackcorp.backpack.notification.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import com.backpackcorp.backpack.notification.dto.PushRequest;
import com.backpackcorp.backpack.notification.repository.DeviceTokenRepository;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.SendResponse;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

// FCM 푸시 발송. 알림이 저장된 트랜잭션이 커밋된 뒤, 요청 스레드가 아닌 별도 스레드에서 보낸다.
// Firebase 키가 없으면(로컬·테스트) FirebaseMessaging 빈이 없으므로 보내지 않는다 (알림함에는 그대로 남는다).
// 앱이 지워져 무효가 된 토큰은 응답을 보고 지운다
@Slf4j
@Component
@RequiredArgsConstructor
public class PushSender {

	// FCM 멀티캐스트 한 번에 보낼 수 있는 최대 토큰 수
	private static final int BATCH = 500;
	private static final Set<MessagingErrorCode> INVALID_TOKEN = Set.of(MessagingErrorCode.UNREGISTERED,
		MessagingErrorCode.INVALID_ARGUMENT, MessagingErrorCode.SENDER_ID_MISMATCH);

	private final ObjectProvider<FirebaseMessaging> firebaseMessaging;
	private final DeviceTokenRepository deviceTokenRepository;

	@Async
	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
	@Transactional(propagation = Propagation.REQUIRES_NEW)
	public void send(PushRequest request) {
		FirebaseMessaging messaging = firebaseMessaging.getIfAvailable();
		if (messaging == null) {
			return;
		}
		List<String> tokens = deviceTokenRepository.findTokensByUserIds(request.userIds());
		List<String> invalid = new ArrayList<>();
		for (int from = 0; from < tokens.size(); from += BATCH) {
			List<String> chunk = tokens.subList(from, Math.min(from + BATCH, tokens.size()));
			MulticastMessage message = MulticastMessage.builder()
				.addAllTokens(chunk)
				.setNotification(com.google.firebase.messaging.Notification.builder()
					.setTitle(request.title())
					.setBody(request.body())
					.build())
				.putAllData(request.data())
				.build();
			try {
				BatchResponse response = messaging.sendEachForMulticast(message);
				List<SendResponse> results = response.getResponses();
				for (int i = 0; i < results.size(); i++) {
					FirebaseMessagingException error = results.get(i).getException();
					if (error != null && INVALID_TOKEN.contains(error.getMessagingErrorCode())) {
						invalid.add(chunk.get(i));
					}
				}
			} catch (FirebaseMessagingException e) {
				log.warn("푸시 발송 실패: code={}, message={}", e.getMessagingErrorCode(), e.getMessage());
			}
		}
		if (!invalid.isEmpty()) {
			deviceTokenRepository.deleteByTokens(invalid);
			log.info("무효한 FCM 토큰 {}개를 지웠습니다", invalid.size());
		}
	}
}
