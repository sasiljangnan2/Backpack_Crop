package com.backpackcorp.backpack.schedule.domain;

import java.time.Duration;
import java.time.LocalTime;

import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import com.backpackcorp.backpack.global.entity.BaseTimeEntity;
import com.backpackcorp.backpack.trip.domain.TripMember;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

// 일정의 실제 진행 기록 (V2). 일정 하나에 기록 하나이고, 기록이 있으면 그 일정은 완료다
@Getter
@Entity
@Table(name = "schedule_activities")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ScheduleActivity extends BaseTimeEntity {

	@OnDelete(action = OnDeleteAction.CASCADE)
	@OneToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "schedule_id", nullable = false, unique = true)
	private Schedule schedule;

	@OnDelete(action = OnDeleteAction.CASCADE)
	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "recorded_by_member_id", nullable = false)
	private TripMember recordedBy;

	// 현지 시각
	@Column(nullable = false)
	private LocalTime actualStartTime;

	@Column(nullable = false)
	private LocalTime actualEndTime;

	// 실제 종료 − 계획 종료(분). 일찍 끝나면 0
	@Column(nullable = false)
	private int delayMin;

	@Builder
	private ScheduleActivity(Schedule schedule, TripMember recordedBy, LocalTime actualStartTime,
		LocalTime actualEndTime) {
		this.schedule = schedule;
		record(recordedBy, actualStartTime, actualEndTime);
	}

	// 다시 기록하면 덮어쓴다. 지연은 그때의 계획 종료 시각으로 다시 계산한다
	public void record(TripMember recordedBy, LocalTime actualStartTime, LocalTime actualEndTime) {
		this.recordedBy = recordedBy;
		this.actualStartTime = actualStartTime;
		this.actualEndTime = actualEndTime;
		this.delayMin = delayMinutes(schedule.getEndTime(), actualEndTime);
	}

	public static int delayMinutes(LocalTime plannedEnd, LocalTime actualEnd) {
		return (int)Math.max(0, Duration.between(plannedEnd, actualEnd).toMinutes());
	}
}
