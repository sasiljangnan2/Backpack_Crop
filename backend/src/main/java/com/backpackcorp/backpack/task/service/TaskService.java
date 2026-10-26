package com.backpackcorp.backpack.task.service;

import java.util.List;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.dto.TripNotificationEvent;
import com.backpackcorp.backpack.task.domain.Task;
import com.backpackcorp.backpack.task.domain.TaskScope;
import com.backpackcorp.backpack.task.dto.TaskCreateRequest;
import com.backpackcorp.backpack.task.dto.TaskResponse;
import com.backpackcorp.backpack.task.dto.TaskUpdateRequest;
import com.backpackcorp.backpack.task.repository.TaskRepository;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.RequiredArgsConstructor;

// 여행 준비 업무 (BP-PR). TEAM은 멤버 모두가 보고 체크하고, PRIVATE은 만든 사람만 본다
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TaskService {

	private final TripMemberGuard tripMemberGuard;
	private final TripMemberRepository tripMemberRepository;
	private final TaskRepository taskRepository;
	private final ApplicationEventPublisher eventPublisher;

	public List<TaskResponse> getTasks(UUID tripId, UUID userId, TaskScope scope) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		return taskRepository.findVisible(tripId, me.getId()).stream()
			.filter(task -> scope == null || task.getScope() == scope)
			.map(task -> TaskResponse.of(task, me.getId()))
			.toList();
	}

	@Transactional
	public TaskResponse createTask(UUID tripId, UUID userId, TaskCreateRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		TripMember assignee = request.scope() == TaskScope.PRIVATE
			? me
			: (request.assigneeMemberId() == null ? null : activeMember(tripId, request.assigneeMemberId()));
		Task task = taskRepository.save(Task.builder()
			.trip(me.getTrip())
			.creator(me)
			.assignee(assignee)
			.scope(request.scope())
			.title(request.title().trim())
			.dueDate(request.dueDate())
			.status(request.status())
			.build());
		notifyAssigned(me, task);
		return TaskResponse.of(task, me.getId());
	}

	@Transactional
	public TaskResponse updateTask(UUID tripId, UUID taskId, UUID userId, TaskUpdateRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Task task = findVisibleTask(tripId, taskId, me);
		if (request.title() != null) {
			if (request.title().isBlank()) {
				throw BaseException.of(ErrorCode.VALIDATION_ERROR, "title", "할 일을 입력해 주세요.");
			}
			task.changeTitle(request.title().trim());
		}
		// 개인 업무의 담당자는 항상 만든 사람이다
		if (task.getScope() == TaskScope.TEAM) {
			UUID before = task.getAssignee() == null ? null : task.getAssignee().getId();
			if (Boolean.TRUE.equals(request.clearAssignee())) {
				task.assign(null);
			} else if (request.assigneeMemberId() != null) {
				task.assign(activeMember(tripId, request.assigneeMemberId()));
			}
			UUID after = task.getAssignee() == null ? null : task.getAssignee().getId();
			if (after != null && !after.equals(before)) {
				notifyAssigned(me, task);
			}
		}
		if (Boolean.TRUE.equals(request.clearDueDate())) {
			task.changeDueDate(null);
		} else if (request.dueDate() != null) {
			task.changeDueDate(request.dueDate());
		}
		if (request.status() != null) {
			task.changeStatus(request.status());
		} else if (request.isDone() != null) {
			task.changeDone(request.isDone());
		}
		taskRepository.flush();
		return TaskResponse.of(task, me.getId());
	}

	// 개인 업무는 만든 사람만, 함께 할 업무는 만든 사람 · 담당자 · 방장이 지울 수 있다
	@Transactional
	public void deleteTask(UUID tripId, UUID taskId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Task task = findVisibleTask(tripId, taskId, me);
		boolean allowed = task.getCreator().getId().equals(me.getId()) || me.isHost()
			|| (task.getAssignee() != null && task.getAssignee().getId().equals(me.getId()));
		if (!allowed) {
			throw new BaseException(ErrorCode.NOT_TASK_OWNER);
		}
		taskRepository.delete(task);
	}

	// 남의 개인 업무는 없는 것과 같다 (존재를 알려 주지 않는다)
	private Task findVisibleTask(UUID tripId, UUID taskId, TripMember me) {
		Task task = taskRepository.findInTrip(taskId, tripId)
			.orElseThrow(() -> new BaseException(ErrorCode.TASK_NOT_FOUND));
		if (task.getScope() == TaskScope.PRIVATE && !task.getCreator().getId().equals(me.getId())) {
			throw new BaseException(ErrorCode.TASK_NOT_FOUND);
		}
		return task;
	}

	private TripMember activeMember(UUID tripId, UUID memberId) {
		return tripMemberRepository.findById(memberId)
			.filter(member -> member.getTrip().getId().equals(tripId) && member.isActive())
			.orElseThrow(() -> BaseException.of(ErrorCode.VALIDATION_ERROR, "assigneeMemberId",
				"이 여행의 멤버에게만 맡길 수 있어요."));
	}

	private void notifyAssigned(TripMember actor, Task task) {
		if (task.getScope() != TaskScope.TEAM || task.getAssignee() == null) {
			return;
		}
		String message = MemberRef.nameOf(actor) + "님이 '" + task.getTitle() + "' 준비를 맡겼어요";
		eventPublisher.publishEvent(TripNotificationEvent.of(actor.getTrip(), actor, NotificationType.TASK_ASSIGNED,
			message, NotificationRefType.TASK, task.getId()).onlyTo(task.getAssignee().getId()));
	}
}
