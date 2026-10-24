package com.backpackcorp.backpack.trip.domain;

import java.math.BigDecimal;
import java.time.Instant;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.springframework.data.annotation.CreatedDate;

import com.backpackcorp.backpack.global.entity.BaseEntity;
import com.backpackcorp.backpack.user.domain.User;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(
	name = "trip_members",
	uniqueConstraints = @UniqueConstraint(name = "uk_trip_members_trip_user", columnNames = {"trip_id", "user_id"})
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TripMember extends BaseEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "trip_id", nullable = false)
	private Trip trip;

	// 게스트는 null
	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "user_id")
	private User user;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 10)
	private TripMemberRole role;

	// 게스트 이름 / 탈퇴 시점 이름 보존
	@Column(length = 20)
	private String displayName;

	// 게스트만
	@JdbcTypeCode(SqlTypes.CHAR)
	@Column(length = 64, unique = true)
	private String guestTokenHash;

	// 본인 선불 환전 환율 (여행 통화 1단위 → KRW)
	@Column(precision = 15, scale = 6)
	private BigDecimal prepaidRate;

	@CreatedDate
	@Column(nullable = false, updatable = false)
	private Instant joinedAt;

	// 나가기. 재참여 시 null로 복구
	private Instant leftAt;

	@Builder
	private TripMember(Trip trip, User user, TripMemberRole role, String displayName, String guestTokenHash,
		BigDecimal prepaidRate) {
		this.trip = trip;
		this.user = user;
		this.role = role;
		this.displayName = displayName;
		this.guestTokenHash = guestTokenHash;
		this.prepaidRate = prepaidRate;
	}
}
