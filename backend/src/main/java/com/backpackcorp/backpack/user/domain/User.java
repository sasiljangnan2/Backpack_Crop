package com.backpackcorp.backpack.user.domain;

import java.time.Instant;

import com.backpackcorp.backpack.global.entity.BaseTimeEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "users")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User extends BaseTimeEntity {

	// 탈퇴 시 익명화한다
	@Column(nullable = false, unique = true)
	private String email;

	@Column(nullable = false)
	private String passwordHash;

	@Column(nullable = false, length = 20)
	private String name;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 10)
	private Role role;

	@Column(nullable = false)
	private boolean notifySchedule = true;

	@Column(nullable = false)
	private boolean notifyExpense = true;

	@Column(nullable = false)
	private boolean notifySettlement = true;

	// soft delete
	private Instant deletedAt;

	@Builder
	private User(String email, String passwordHash, String name, Role role) {
		this.email = email;
		this.passwordHash = passwordHash;
		this.name = name;
		this.role = role != null ? role : Role.USER;
	}
}
