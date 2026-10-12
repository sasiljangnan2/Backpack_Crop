package com.backpackcorp.backpack.global.entity;

import java.util.UUID;

import org.hibernate.annotations.UuidGenerator;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;

// id BINARY(16) PK. 복합 PK인 expense_item_users 만 상속하지 않는다
// 시각 컬럼이 없거나 이름이 다른 테이블은 이 클래스를 직접 상속한다:
// trip_members(joined_at), exchange_rates(fetched_at), poll_options, expense_items, settlement_transfers,
// device_tokens · poll_votes(updated_at 만 있음 → 엔티티에 직접 선언)
// 감사 리스너는 여기 한 번만 둔다. 하위 엔티티는 @CreatedDate / @LastModifiedDate만 붙이면 값이 채워진다
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

	// UUID v7은 시간순이라 인덱스에 순서대로 쌓인다
	@Id
	@UuidGenerator(style = UuidGenerator.Style.VERSION_7)
	@Column(nullable = false, updatable = false)
	private UUID id;
}
