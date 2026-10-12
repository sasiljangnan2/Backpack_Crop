package com.backpackcorp.backpack.global.entity;

import java.time.Instant;

import org.springframework.data.annotation.CreatedDate;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;

// id + created_at 만 있는 테이블용: notifications, polls, budget_items, settlement_shares
@Getter
@MappedSuperclass
public abstract class BaseCreatedEntity extends BaseEntity {

	@CreatedDate
	@Column(nullable = false, updatable = false)
	private Instant createdAt;
}
