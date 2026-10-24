package com.backpackcorp.backpack.poll.domain;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import com.backpackcorp.backpack.global.entity.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
	name = "poll_options",
	uniqueConstraints = @UniqueConstraint(name = "uk_poll_options_order", columnNames = {"poll_id", "sort_order"})
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PollOption extends BaseEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "poll_id", nullable = false)
	private Poll poll;

	@Column(nullable = false, length = 100)
	private String label;

	// 도보·대기·비용 등 (선택)
	private String memo;

	// 1~6
	@JdbcTypeCode(SqlTypes.TINYINT)
	@Column(nullable = false)
	private int sortOrder;

	@Builder
	private PollOption(Poll poll, String label, String memo, int sortOrder) {
		this.poll = poll;
		this.label = label;
		this.memo = memo;
		this.sortOrder = sortOrder;
	}
}
