package com.backpackcorp.backpack.notification.domain;

// notifications.type 컬럼 값 (VARCHAR(30), DB에 CHECK 제약 없음)
public enum NotificationType {
	SCHEDULE_CHANGED,
	EXPENSE_ADDED,
	SETTLEMENT_SHARED,
	TRIP_DELETED,
	// 아래는 V1 이후 추가 (컬럼에 CHECK 제약이 없어 마이그레이션 없이 쓸 수 있다)
	POLL_CREATED,
	POLL_CLOSED,
	TASK_ASSIGNED,
	MEMBER_JOINED
}
