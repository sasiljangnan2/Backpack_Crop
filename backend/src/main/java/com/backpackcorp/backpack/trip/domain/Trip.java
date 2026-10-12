package com.backpackcorp.backpack.trip.domain;

import java.time.LocalDate;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import com.backpackcorp.backpack.global.entity.BaseTimeEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "trips")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Trip extends BaseTimeEntity {

	@Column(nullable = false, length = 50)
	private String name;

	@Column(nullable = false, length = 100)
	private String destination;

	@Column(nullable = false)
	private LocalDate startDate;

	@Column(nullable = false)
	private LocalDate endDate;

	// 여행지 통화 1개 (ISO 4217)
	@JdbcTypeCode(SqlTypes.CHAR)
	@Column(nullable = false, length = 3)
	private String currencyCode;

	@JdbcTypeCode(SqlTypes.CHAR)
	@Column(nullable = false, length = 8, unique = true)
	private String inviteCode;

	@Builder
	private Trip(String name, String destination, LocalDate startDate, LocalDate endDate, String currencyCode,
		String inviteCode) {
		this.name = name;
		this.destination = destination;
		this.startDate = startDate;
		this.endDate = endDate;
		this.currencyCode = currencyCode;
		this.inviteCode = inviteCode;
	}
}
