package com.backpackcorp.backpack.schedule.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;

import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import com.backpackcorp.backpack.global.entity.BaseTimeEntity;
import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.domain.PlaceCategory;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "schedules")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Schedule extends BaseTimeEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "trip_id", nullable = false)
	private Trip trip;

	// day는 H2 등에서 예약어라 인용한다
	@Column(name = "`day`", nullable = false)
	private LocalDate day;

	// 종료는 시작보다 늦어야 한다 (자정을 넘는 일정 불가)
	@Column(nullable = false)
	private LocalTime startTime;

	@Column(nullable = false)
	private LocalTime endTime;

	@Column(nullable = false, length = 100)
	private String title;

	@Column(length = 100)
	private String placeText;

	// 장소 검색에서 고른 좌표 · 분류 (V4). 장소를 글자로만 적으면 비어 있다
	@Column(precision = 9, scale = 6)
	private BigDecimal placeLat;

	@Column(precision = 9, scale = 6)
	private BigDecimal placeLng;

	@Enumerated(EnumType.STRING)
	@Column(length = 12)
	private PlaceCategory placeCategory;

	@Column(name = "is_locked", nullable = false)
	private boolean locked;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 10)
	private ReservationStatus reservationStatus = ReservationStatus.NONE;

	@Column(length = 500)
	private String memo;

	// AI 재구성으로 바뀐 시각 (BP-AI-003 "재구성" 배지). 사람이 고치면 지운다
	private Instant replannedAt;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "created_by_member_id", nullable = false)
	private TripMember createdBy;

	// 낙관적 락
	@Version
	@Column(nullable = false)
	private int version;

	@Builder
	private Schedule(Trip trip, LocalDate day, LocalTime startTime, LocalTime endTime, String title, String placeText,
		LatLng place, PlaceCategory placeCategory, String memo, TripMember createdBy, Boolean locked,
		ReservationStatus reservationStatus) {
		this.trip = trip;
		this.day = day;
		this.startTime = startTime;
		this.endTime = endTime;
		this.title = title;
		changePlace(placeText, place, placeCategory);
		this.memo = memo;
		this.createdBy = createdBy;
		this.locked = locked != null && locked;
		this.reservationStatus = reservationStatus != null ? reservationStatus : ReservationStatus.NONE;
	}

	public void changeTime(LocalDate day, LocalTime startTime, LocalTime endTime) {
		this.day = day;
		this.startTime = startTime;
		this.endTime = endTime;
	}

	public void changeDetails(String title, String memo, ReservationStatus reservationStatus) {
		this.title = title;
		this.memo = memo;
		this.reservationStatus = reservationStatus;
	}

	// 좌표 없이 글자만 바꾸면 좌표 · 분류는 지운다 (다른 곳을 가리키게 되므로)
	public void changePlace(String placeText, LatLng place, PlaceCategory category) {
		this.placeText = placeText;
		boolean hasPlace = placeText != null && place != null;
		this.placeLat = hasPlace ? LatLng.scaled(place.lat()) : null;
		this.placeLng = hasPlace ? LatLng.scaled(place.lng()) : null;
		this.placeCategory = hasPlace ? category : null;
	}

	public LatLng place() {
		return LatLng.of(placeLat, placeLng);
	}

	public void markReplanned(Instant at) {
		this.replannedAt = at;
	}

	public void clearReplanned() {
		this.replannedAt = null;
	}

	public void changeLocked(boolean locked) {
		this.locked = locked;
	}

	// [start, end) 구간이 겹치는지. 끝나는 시각에 다음 일정이 시작하는 것은 겹침이 아니다
	public boolean overlaps(LocalTime start, LocalTime end) {
		return start.isBefore(endTime) && end.isAfter(startTime);
	}
}
