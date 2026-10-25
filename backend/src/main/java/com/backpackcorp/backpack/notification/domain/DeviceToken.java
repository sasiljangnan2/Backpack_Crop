package com.backpackcorp.backpack.notification.domain;

import java.time.Instant;

import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
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
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "user_id")
	private User user;

	@ManyToOne(fetch = FetchType.LAZY)
	@OnDelete(action = OnDeleteAction.CASCADE)
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

	// 같은 기기에서 다른 계정으로 로그인하면 토큰을 지금 계정으로 옮긴다
	public void assignTo(User user, Instant now) {
		this.user = user;
		this.member = null;
		this.updatedAt = now;
	}
}
