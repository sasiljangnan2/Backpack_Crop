package com.backpackcorp.backpack.global.entity;

import java.time.Instant;

import org.springframework.data.annotation.LastModifiedDate;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;

// id + created_at + updated_at 이 있는 테이블용: users, trips, tasks, schedules, expenses
@Getter
@MappedSuperclass
public abstract class BaseTimeEntity extends BaseCreatedEntity {

	@LastModifiedDate
	@Column(nullable = false)
	private Instant updatedAt;
}
