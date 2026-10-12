package com.backpackcorp.backpack.notification.domain;

// notifications.type 컬럼 값 (VARCHAR(30), DB에 CHECK 제약 없음)
public enum NotificationType {
	SCHEDULE_CHANGED,
	EXPENSE_ADDED,
	SETTLEMENT_SHARED,
	TRIP_DELETED
}
