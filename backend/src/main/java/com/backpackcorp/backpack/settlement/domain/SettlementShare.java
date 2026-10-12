package com.backpackcorp.backpack.settlement.domain;

import com.backpackcorp.backpack.global.entity.BaseCreatedEntity;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;

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
@Table(name = "settlement_shares")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SettlementShare extends BaseCreatedEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "trip_id", nullable = false)
	private Trip trip;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "shared_by_member_id", nullable = false)
	private TripMember sharedBy;

	@Builder
	private SettlementShare(Trip trip, TripMember sharedBy) {
		this.trip = trip;
		this.sharedBy = sharedBy;
	}
}
