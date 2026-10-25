package com.backpackcorp.backpack.task.dto;

import java.time.Instant;
import java.util.UUID;

import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.task.domain.Task;
import com.backpackcorp.backpack.task.domain.TaskScope;

public record TaskResponse(
	UUID id,
	TaskScope scope,
	String title,
	boolean isDone,
	MemberRef creator,
	MemberRef assignee,
	boolean isMine,
	Instant createdAt,
	Instant updatedAt
) {

	// isMine: 내가 만들었거나 내가 맡은 업무
	public static TaskResponse of(Task task, UUID myMemberId) {
		boolean mine = task.getCreator().getId().equals(myMemberId)
			|| (task.getAssignee() != null && task.getAssignee().getId().equals(myMemberId));
		return new TaskResponse(task.getId(), task.getScope(), task.getTitle(), task.isDone(),
			MemberRef.from(task.getCreator()), task.getAssignee() == null ? null : MemberRef.from(task.getAssignee()),
			mine, task.getCreatedAt(), task.getUpdatedAt());
	}
}
