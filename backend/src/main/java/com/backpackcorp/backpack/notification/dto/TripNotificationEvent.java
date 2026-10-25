package com.backpackcorp.backpack.notification.dto;

import java.util.Set;
import java.util.UUID;

import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;

// 여행 안에서 일어난 일. 각 서비스가 ApplicationEventPublisher로 보내면 NotificationService가
// 같은 트랜잭션에서 멤버들의 알림함에 넣고, 커밋 뒤 푸시를 보낸다.
// actorMemberId: 일을 한 사람. 본인에게는 보내지 않는다
// onlyMemberIds: null이면 여행 멤버 전원, 값이 있으면 그 멤버들에게만 (예: 준비 업무 담당자)
public record TripNotificationEvent(
	UUID tripId,
	String tripName,
	UUID actorMemberId,
	NotificationType type,
	String message,
	NotificationRefType refType,
	UUID refId,
	Set<UUID> onlyMemberIds
) {

	public static TripNotificationEvent of(Trip trip, TripMember actor, NotificationType type, String message,
		NotificationRefType refType, UUID refId) {
		return new TripNotificationEvent(trip.getId(), trip.getName(), actor == null ? null : actor.getId(), type,
			message, refType, refId, null);
	}

	public TripNotificationEvent onlyTo(UUID memberId) {
		return new TripNotificationEvent(tripId, tripName, actorMemberId, type, message, refType, refId,
			Set.of(memberId));
	}
}
