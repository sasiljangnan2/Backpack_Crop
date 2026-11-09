package com.backpackcorp.backpack.task.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.task.domain.TaskScope;
import com.backpackcorp.backpack.task.dto.TaskCreateRequest;
import com.backpackcorp.backpack.task.dto.TaskResponse;
import com.backpackcorp.backpack.task.dto.TaskUpdateRequest;
import com.backpackcorp.backpack.task.service.TaskService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}/tasks")
public class TaskController {

	private final TaskService taskService;

	// ?scope=TEAM|PRIVATE (생략하면 둘 다)
	@GetMapping
	public List<TaskResponse> getTasks(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@RequestParam(required = false) TaskScope scope) {
		return taskService.getTasks(tripId, BackpackUserDetails.requireId(user), scope);
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public TaskResponse createTask(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@Valid @RequestBody TaskCreateRequest request) {
		return taskService.createTask(tripId, BackpackUserDetails.requireId(user), request);
	}

	@PatchMapping("/{taskId}")
	public TaskResponse updateTask(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID taskId, @Valid @RequestBody TaskUpdateRequest request) {
		return taskService.updateTask(tripId, taskId, BackpackUserDetails.requireId(user), request);
	}

	@DeleteMapping("/{taskId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void deleteTask(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID taskId) {
		taskService.deleteTask(tripId, taskId, BackpackUserDetails.requireId(user));
	}
}
