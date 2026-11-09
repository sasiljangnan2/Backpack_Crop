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

	public boolean isDeleted() {
		return deletedAt != null;
	}

	public void changeName(String name) {
		this.name = name;
	}

	public void changePasswordHash(String passwordHash) {
		this.passwordHash = passwordHash;
	}

	// null인 값은 그대로 둔다
	public void changeNotificationSettings(Boolean schedule, Boolean expense, Boolean settlement) {
		if (schedule != null) {
			this.notifySchedule = schedule;
		}
		if (expense != null) {
			this.notifyExpense = expense;
		}
		if (settlement != null) {
			this.notifySettlement = settlement;
		}
	}

	// 같은 이메일로 다시 가입할 수 있도록 이메일을 익명화하고, 비밀번호로 로그인할 수 없게 한다
	public void withdraw(Instant now, String anonymizedEmail, String unusablePasswordHash) {
		this.deletedAt = now;
		this.email = anonymizedEmail;
		this.passwordHash = unusablePasswordHash;
	}
}
