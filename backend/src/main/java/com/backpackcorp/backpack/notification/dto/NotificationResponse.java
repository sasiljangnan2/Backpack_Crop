package com.backpackcorp.backpack.notification.dto;

import java.time.Instant;
import java.util.UUID;

import com.backpackcorp.backpack.notification.domain.Notification;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;

// 알림을 누르면 앱은 refType + refId 화면으로 이동한다 (TRIP_DELETED는 refType이 null)
public record NotificationResponse(
	UUID id,
	UUID tripId,
	String tripName,
	NotificationType type,
	String message,
	NotificationRefType refType,
	UUID refId,
	boolean isRead,
	Instant createdAt
) {

	public static NotificationResponse from(Notification notification) {
		return new NotificationResponse(notification.getId(), notification.getTripId(), notification.getTripName(),
			notification.getType(), notification.getMessage(), notification.getRefType(), notification.getRefId(),
			notification.isRead(), notification.getCreatedAt());
	}
}
