package com.backpackcorp.backpack.notification.service;

import java.time.Clock;
import java.time.Instant;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.global.dto.SliceCursorPageResponse;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.notification.domain.DeviceToken;
import com.backpackcorp.backpack.notification.domain.Notification;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.dto.NotificationResponse;
import com.backpackcorp.backpack.notification.dto.PushRequest;
import com.backpackcorp.backpack.notification.dto.TripNotificationEvent;
import com.backpackcorp.backpack.notification.repository.DeviceTokenRepository;
import com.backpackcorp.backpack.notification.repository.NotificationRepository;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

// 알림함과 기기 토큰.
// 여행 안에서 일이 생기면(TripNotificationEvent) 같은 트랜잭션에서 멤버들의 알림을 저장하고,
// 푸시는 커밋된 뒤 PushSender가 따로 보낸다 (푸시가 실패해도 원래 작업은 취소되지 않는다)
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationService {

	private final NotificationRepository notificationRepository;
	private final DeviceTokenRepository deviceTokenRepository;
	private final TripMemberRepository tripMemberRepository;
	private final UserRepository userRepository;
	private final ApplicationEventPublisher eventPublisher;
	private final Clock clock;

	// 이벤트를 보낸 서비스의 트랜잭션 안에서 실행된다
	@EventListener
	@Transactional
	public void onTripEvent(TripNotificationEvent event) {
		Set<UUID> recipients = new LinkedHashSet<>();
		for (TripMember member : tripMemberRepository.findAllWithUserByTripId(event.tripId())) {
			User user = member.getUser();
			boolean skip = !member.isActive() || user == null || user.isDeleted()
				|| member.getId().equals(event.actorMemberId()) || !wants(user, event.type())
				|| (event.onlyMemberIds() != null && !event.onlyMemberIds().contains(member.getId()));
			if (skip) {
				continue;
			}
			notificationRepository.save(Notification.builder()
				.user(user)
				.tripId(event.tripId())
				.tripName(event.tripName())
				.type(event.type())
				.message(truncate(event.message()))
				.refType(event.refType())
				.refId(event.refId())
				.build());
			recipients.add(user.getId());
		}
		if (recipients.isEmpty()) {
			return;
		}
		Map<String, String> data = new HashMap<>();
		data.put("tripId", event.tripId().toString());
		data.put("type", event.type().name());
		if (event.refType() != null) {
			data.put("refType", event.refType().name());
		}
		if (event.refId() != null) {
			data.put("refId", event.refId().toString());
		}
		eventPublisher.publishEvent(new PushRequest(recipients, event.tripName(), event.message(), data));
	}

	public SliceCursorPageResponse<NotificationResponse> getNotifications(UUID userId, UUID cursor, int size) {
		PageRequest page = PageRequest.of(0, size);
		Slice<Notification> slice = cursor == null
			? notificationRepository.findByUserIdOrderByIdDesc(userId, page)
			: notificationRepository.findByUserIdAndIdLessThanOrderByIdDesc(userId, cursor, page);
		return SliceCursorPageResponse.from(slice.map(NotificationResponse::from), NotificationResponse::id);
	}

	public long countUnread(UUID userId) {
		return notificationRepository.countByUserIdAndReadFalse(userId);
	}

	@Transactional
	public void markRead(UUID userId, UUID notificationId) {
		notificationRepository.findByIdAndUserId(notificationId, userId)
			.orElseThrow(() -> new BaseException(ErrorCode.NOTIFICATION_NOT_FOUND))
			.markRead();
	}

	@Transactional
	public void markAllRead(UUID userId) {
		notificationRepository.markAllRead(userId);
	}

	// 로그인·앱 실행 때 부른다. 같은 토큰이 다른 계정에 있으면 지금 계정으로 옮긴다
	@Transactional
	public void registerDeviceToken(UUID userId, String fcmToken) {
		User user = userRepository.findById(userId)
			.filter(found -> !found.isDeleted())
			.orElseThrow(() -> new BaseException(ErrorCode.USER_NOT_FOUND));
		String token = fcmToken.trim();
		deviceTokenRepository.findByFcmToken(token).ifPresentOrElse(
			existing -> existing.assignTo(user, Instant.now(clock)),
			() -> deviceTokenRepository.save(DeviceToken.builder().user(user).fcmToken(token).build()));
	}

	// 로그아웃 때 부른다. 다른 계정의 토큰은 지우지 않는다
	@Transactional
	public void removeDeviceToken(UUID userId, String fcmToken) {
		deviceTokenRepository.deleteByTokenAndUser(fcmToken.trim(), userId);
	}

	// 회원의 알림 설정. 여행 삭제·멤버 참여처럼 설정과 상관없는 알림은 항상 보낸다
	private static boolean wants(User user, NotificationType type) {
		return switch (type) {
			case SCHEDULE_CHANGED, POLL_CREATED, POLL_CLOSED, TASK_ASSIGNED -> user.isNotifySchedule();
			case EXPENSE_ADDED -> user.isNotifyExpense();
			case SETTLEMENT_SHARED -> user.isNotifySettlement();
			case TRIP_DELETED, MEMBER_JOINED -> true;
		};
	}

	// notifications.message는 255자
	private static String truncate(String message) {
		return message.length() <= 255 ? message : message.substring(0, 254) + "…";
	}
}
