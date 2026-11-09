package com.backpackcorp.backpack.user.dto;

import java.time.Instant;
import java.util.UUID;

import com.backpackcorp.backpack.user.domain.User;

public record UserResponse(
	UUID id,
	String email,
	String name,
	boolean notifySchedule,
	boolean notifyExpense,
	boolean notifySettlement,
	Instant createdAt
) {

	public static UserResponse from(User user) {
		return new UserResponse(user.getId(), user.getEmail(), user.getName(), user.isNotifySchedule(),
			user.isNotifyExpense(), user.isNotifySettlement(), user.getCreatedAt());
	}
}
