package com.backpackcorp.backpack.poll.domain;

import java.time.Instant;

import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import org.springframework.data.annotation.LastModifiedDate;

import com.backpackcorp.backpack.global.entity.BaseEntity;
import com.backpackcorp.backpack.trip.domain.TripMember;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(
	name = "poll_votes",
	// 1인 1표
	uniqueConstraints = @UniqueConstraint(name = "uk_poll_votes_one_per_member", columnNames = {"poll_id", "member_id"})
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PollVote extends BaseEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "poll_id", nullable = false)
	private Poll poll;

	// 같은 투표의 후보여야 한다 (애플리케이션에서 검증)
	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "option_id", nullable = false)
	private PollOption option;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "member_id", nullable = false)
	private TripMember member;

	@LastModifiedDate
	@Column(nullable = false)
	private Instant updatedAt;

	@Builder
	private PollVote(Poll poll, PollOption option, TripMember member) {
		this.poll = poll;
		this.option = option;
		this.member = member;
	}

	public void changeOption(PollOption option) {
		this.option = option;
	}
}
