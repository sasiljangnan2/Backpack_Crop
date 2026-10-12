package com.backpackcorp.backpack.notification.domain;

import java.util.UUID;

import com.backpackcorp.backpack.global.entity.BaseCreatedEntity;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.user.domain.User;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "notifications")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Notification extends BaseCreatedEntity {

	// user(회원 수신자) / member(게스트 수신자) 중 정확히 하나만 값이 있어야 한다 (애플리케이션에서 검증)
	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "user_id")
	private User user;

	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "member_id")
	private TripMember member;

	// FK가 없다: 여행이 삭제된 뒤에도 알림을 보존하기 위해 ID만 저장한다
	@Column(nullable = false)
	private UUID tripId;

	// 스냅샷
	@Column(nullable = false, length = 50)
	private String tripName;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 30)
	private NotificationType type;

	@Column(nullable = false)
	private String message;

	// 눌렀을 때 이동 대상
	@Enumerated(EnumType.STRING)
	@Column(length = 30)
	private NotificationRefType refType;

	private UUID refId;

	@Column(name = "is_read", nullable = false)
	private boolean read;

	@Builder
	private Notification(User user, TripMember member, UUID tripId, String tripName, NotificationType type,
		String message, NotificationRefType refType, UUID refId) {
		this.user = user;
		this.member = member;
		this.tripId = tripId;
		this.tripName = tripName;
		this.type = type;
		this.message = message;
		this.refType = refType;
		this.refId = refId;
	}
}
