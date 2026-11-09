package com.backpackcorp.backpack.task.dto;

import java.time.LocalDate;
import java.util.UUID;

import com.backpackcorp.backpack.task.domain.TaskScope;
import com.backpackcorp.backpack.task.domain.TaskStatus;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

// PRIVATE(개인) 업무는 담당자를 받지 않는다 (항상 나)
public record TaskCreateRequest(
	@NotNull(message = "개인 업무인지 함께 할 업무인지 선택해 주세요.")
	TaskScope scope,

	@NotBlank(message = "할 일을 입력해 주세요.")
	@Size(max = 100, message = "할 일은 100자 이하로 입력해 주세요.")
	String title,

	UUID assigneeMemberId,

	// 선택. 앱은 함께 할 업무에서 필수로 받는다 (스토리보드 BP-PR-002)
	LocalDate dueDate,

	// 선택. 기본 할 일(TODO)
	TaskStatus status
) {
}
