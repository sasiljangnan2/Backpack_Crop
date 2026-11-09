package com.backpackcorp.backpack.task.dto;

import java.time.LocalDate;
import java.util.UUID;

import com.backpackcorp.backpack.task.domain.TaskStatus;

import jakarta.validation.constraints.Size;

// 보낸 값만 바뀐다. 담당자 · 마감일을 비우려면 clearAssignee · clearDueDate를 true로 보낸다.
// isDone과 status를 같이 보내면 status가 이긴다
public record TaskUpdateRequest(
	@Size(min = 1, max = 100, message = "할 일은 1~100자로 입력해 주세요.")
	String title,

	UUID assigneeMemberId,

	Boolean clearAssignee,

	Boolean isDone,

	LocalDate dueDate,

	Boolean clearDueDate,

	TaskStatus status
) {
}
