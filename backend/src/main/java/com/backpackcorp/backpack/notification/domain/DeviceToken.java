package com.backpackcorp.backpack.notification.domain;

import java.time.Instant;

import org.springframework.data.annotation.LastModifiedDate;

import com.backpackcorp.backpack.global.entity.BaseEntity;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.user.domain.User;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
@Table(name = "device_tokens")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class DeviceToken extends BaseEntity {

	// user(회원) / member(게스트) 중 정확히 하나만 값이 있어야 한다 (애플리케이션에서 검증)
	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "user_id")
	private User user;

	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "member_id")
	private TripMember member;

	@Column(nullable = false, unique = true)
	private String fcmToken;

	@LastModifiedDate
	@Column(nullable = false)
	private Instant updatedAt;

	@Builder
	private DeviceToken(User user, TripMember member, String fcmToken) {
		this.user = user;
		this.member = member;
		this.fcmToken = fcmToken;
	}
}
