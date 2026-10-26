package com.backpackcorp.backpack.user.dto;

import java.util.UUID;

import com.backpackcorp.backpack.user.domain.User;

// 내 정보 응답. 이름 변경 · 알림 설정 변경 API도 이 형식으로 돌려준다
public record UserResponse(
	UUID id,
	String email,
	String name,
	boolean notifySchedule,
	boolean notifyExpense,
	boolean notifySettlement
) {

	// boolean 필드는 Lombok이 getXxx가 아니라 isXxx로 getter를 만든다
	public static UserResponse from(User user) {
		return new UserResponse(user.getId(), user.getEmail(), user.getName(),
			user.isNotifySchedule(), user.isNotifyExpense(), user.isNotifySettlement());
	}
}
