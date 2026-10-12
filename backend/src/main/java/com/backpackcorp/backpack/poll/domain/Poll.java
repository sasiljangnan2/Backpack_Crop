package com.backpackcorp.backpack.poll.domain;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;

import com.backpackcorp.backpack.global.entity.BaseCreatedEntity;
import com.backpackcorp.backpack.schedule.domain.Schedule;
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

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "polls")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Poll extends BaseCreatedEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "trip_id", nullable = false)
	private Trip trip;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "creator_member_id", nullable = false)
	private TripMember creator;

	@Column(nullable = false, length = 100)
	private String title;

	// 반영할 일정 슬롯
	@Column(nullable = false)
	private LocalDate slotDate;

	@Column(nullable = false)
	private LocalTime slotStart;

	@Column(nullable = false)
	private LocalTime slotEnd;

	// 마감 시간
	private Instant deadlineAt;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 10)
	private PollStatus status = PollStatus.OPEN;

	// 같은 투표의 후보여야 한다 (애플리케이션에서 검증)
	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "selected_option_id")
	private PollOption selectedOption;

	// 반영된 일정
	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "schedule_id")
	private Schedule schedule;

	private Instant closedAt;

	@Builder
	private Poll(Trip trip, TripMember creator, String title, LocalDate slotDate, LocalTime slotStart,
		LocalTime slotEnd, Instant deadlineAt) {
		this.trip = trip;
		this.creator = creator;
		this.title = title;
		this.slotDate = slotDate;
		this.slotStart = slotStart;
		this.slotEnd = slotEnd;
		this.deadlineAt = deadlineAt;
	}
}
