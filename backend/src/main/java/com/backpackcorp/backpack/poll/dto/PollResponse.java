package com.backpackcorp.backpack.poll.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.poll.domain.PollStatus;
import com.fasterxml.jackson.annotation.JsonFormat;

// 투표 상세 (목록도 같은 형식을 쓴다. 인원이 적어 후보·투표자를 함께 내려도 가볍다).
// isVotingOpen: 상태가 OPEN이고 마감 시각이 지나지 않았을 때만 true
// canManage: 마감·삭제 버튼을 보여 줄지 (만든 사람 · 방장)
public record PollResponse(
	UUID id,
	String title,
	LocalDate slotDate,
	@JsonFormat(pattern = "HH:mm") LocalTime slotStart,
	@JsonFormat(pattern = "HH:mm") LocalTime slotEnd,
	Instant deadlineAt,
	PollStatus status,
	boolean isVotingOpen,
	MemberRef creator,
	boolean canManage,
	List<OptionResponse> options,
	int voteCount,
	int memberCount,
	UUID myOptionId,
	UUID selectedOptionId,
	UUID scheduleId,
	Instant createdAt,
	Instant closedAt
) {

	// isLeading: 가장 많이 받은 후보 (동점이면 모두 true, 0표면 false)
	public record OptionResponse(
		UUID id,
		String label,
		String memo,
		int sortOrder,
		int voteCount,
		boolean isLeading,
		List<MemberRef> voters
	) {
	}
}
