package com.backpackcorp.backpack.user.dto;

// 보낸 값만 바뀐다
public record NotificationSettingsRequest(
	Boolean notifySchedule,
	Boolean notifyExpense,
	Boolean notifySettlement
) {
}
