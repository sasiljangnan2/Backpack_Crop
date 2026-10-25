package com.backpackcorp.backpack.task.domain;

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

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "tasks")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Task extends BaseTimeEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "trip_id", nullable = false)
	private Trip trip;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "creator_member_id", nullable = false)
	private TripMember creator;

	// 미지정 허용
	@ManyToOne(fetch = FetchType.LAZY)
	@OnDelete(action = OnDeleteAction.SET_NULL)
	@JoinColumn(name = "assignee_member_id")
	private TripMember assignee;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 10)
	private TaskScope scope;

	@Column(nullable = false, length = 100)
	private String title;

	@Column(name = "is_done", nullable = false)
	private boolean done;

	@Builder
	private Task(Trip trip, TripMember creator, TripMember assignee, TaskScope scope, String title) {
		this.trip = trip;
		this.creator = creator;
		this.assignee = assignee;
		this.scope = scope;
		this.title = title;
	}

	public void changeTitle(String title) {
		this.title = title;
	}

	// null이면 담당자를 비운다
	public void assign(TripMember assignee) {
		this.assignee = assignee;
	}

	public void changeDone(boolean done) {
		this.done = done;
	}
}
