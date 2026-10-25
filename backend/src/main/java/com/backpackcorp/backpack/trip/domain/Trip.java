package com.backpackcorp.backpack.trip.domain;

import java.time.LocalDate;
import java.time.ZoneId;

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

	public static final String DEFAULT_TIME_ZONE = "Asia/Seoul";

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

	// 여행지 IANA 시간대 (예: Asia/Tokyo). 일정의 날짜·시각이 이 시간대 기준이다
	@Column(nullable = false, length = 40)
	private String timeZone;

	@JdbcTypeCode(SqlTypes.CHAR)
	@Column(nullable = false, length = 8, unique = true)
	private String inviteCode;

	@Builder
	private Trip(String name, String destination, LocalDate startDate, LocalDate endDate, String currencyCode,
		String timeZone, String inviteCode) {
		this.name = name;
		this.destination = destination;
		this.startDate = startDate;
		this.endDate = endDate;
		this.currencyCode = currencyCode;
		this.timeZone = timeZone != null ? timeZone : DEFAULT_TIME_ZONE;
		this.inviteCode = inviteCode;
	}

	public void changeInfo(String name, String destination) {
		this.name = name;
		this.destination = destination;
	}

	public void changePeriod(LocalDate startDate, LocalDate endDate) {
		this.startDate = startDate;
		this.endDate = endDate;
	}

	public void changeCurrency(String currencyCode) {
		this.currencyCode = currencyCode;
	}

	public void changeTimeZone(String timeZone) {
		this.timeZone = timeZone;
	}

	public ZoneId zoneId() {
		return ZoneId.of(timeZone);
	}

	// 여행지 기준 오늘이 여행 전·중·후 중 어디인지
	public TripStatus statusOn(LocalDate today) {
		if (today.isBefore(startDate)) {
			return TripStatus.UPCOMING;
		}
		return today.isAfter(endDate) ? TripStatus.DONE : TripStatus.LIVE;
	}

	public boolean contains(LocalDate day) {
		return !day.isBefore(startDate) && !day.isAfter(endDate);
	}
}
