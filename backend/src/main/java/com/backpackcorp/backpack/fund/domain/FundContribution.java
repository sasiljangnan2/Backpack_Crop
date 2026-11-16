package com.backpackcorp.backpack.fund.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import com.backpackcorp.backpack.global.entity.BaseTimeEntity;
import com.backpackcorp.backpack.trip.domain.Trip;
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

// 공금에 모은 돈 한 건
@Getter
@Entity
@Table(name = "fund_contributions")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FundContribution extends BaseTimeEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "trip_id", nullable = false)
	private Trip trip;

	// 돈을 낸 사람
	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "member_id", nullable = false)
	private TripMember member;

	// 입력한 사람
	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "creator_member_id", nullable = false)
	private TripMember creator;

	@Column(nullable = false, precision = 15, scale = 0)
	private BigDecimal amountKrw;

	@Column(nullable = false)
	private LocalDate contributedOn;

	@Column(length = 100)
	private String memo;

	@Builder
	private FundContribution(Trip trip, TripMember member, TripMember creator, BigDecimal amountKrw,
		LocalDate contributedOn, String memo) {
		this.trip = trip;
		this.member = member;
		this.creator = creator;
		this.amountKrw = amountKrw;
		this.contributedOn = contributedOn;
		this.memo = memo;
	}

	public void update(TripMember member, BigDecimal amountKrw, LocalDate contributedOn, String memo) {
		this.member = member;
		this.amountKrw = amountKrw;
		this.contributedOn = contributedOn;
		this.memo = memo;
	}
}
