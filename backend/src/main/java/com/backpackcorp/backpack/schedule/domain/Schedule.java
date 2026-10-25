package com.backpackcorp.backpack.schedule.domain;

import java.time.LocalDate;
import java.time.LocalTime;

import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import com.backpackcorp.backpack.global.entity.BaseTimeEntity;
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

	@Column(name = "is_locked", nullable = false)
	private boolean locked;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 10)
	private ReservationStatus reservationStatus = ReservationStatus.NONE;

	@Column(length = 500)
	private String memo;

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
		String memo, TripMember createdBy, Boolean locked, ReservationStatus reservationStatus) {
		this.trip = trip;
		this.day = day;
		this.startTime = startTime;
		this.endTime = endTime;
		this.title = title;
		this.placeText = placeText;
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

	public void changeDetails(String title, String placeText, String memo, ReservationStatus reservationStatus) {
		this.title = title;
		this.placeText = placeText;
		this.memo = memo;
		this.reservationStatus = reservationStatus;
	}

	public void changeLocked(boolean locked) {
		this.locked = locked;
	}

	// [start, end) 구간이 겹치는지. 끝나는 시각에 다음 일정이 시작하는 것은 겹침이 아니다
	public boolean overlaps(LocalTime start, LocalTime end) {
		return start.isBefore(endTime) && end.isAfter(startTime);
	}
}
