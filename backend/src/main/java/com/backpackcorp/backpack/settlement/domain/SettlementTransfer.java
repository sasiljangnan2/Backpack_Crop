package com.backpackcorp.backpack.settlement.domain;

import java.math.BigDecimal;

import com.backpackcorp.backpack.global.entity.BaseEntity;
import com.backpackcorp.backpack.trip.domain.TripMember;

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
@Table(name = "settlement_transfers")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SettlementTransfer extends BaseEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "share_id", nullable = false)
	private SettlementShare share;

	// 보내는 사람과 받는 사람은 달라야 한다 (애플리케이션에서 검증)
	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "from_member_id", nullable = false)
	private TripMember fromMember;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "to_member_id", nullable = false)
	private TripMember toMember;

	// 0보다 커야 한다 (ck_settlement_transfers_amount)
	@Column(nullable = false, precision = 15, scale = 0)
	private BigDecimal amountKrw;

	@Builder
	private SettlementTransfer(SettlementShare share, TripMember fromMember, TripMember toMember,
		BigDecimal amountKrw) {
		this.share = share;
		this.fromMember = fromMember;
		this.toMember = toMember;
		this.amountKrw = amountKrw;
	}
}
