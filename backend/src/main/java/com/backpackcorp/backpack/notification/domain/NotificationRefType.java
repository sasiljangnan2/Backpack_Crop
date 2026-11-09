package com.backpackcorp.backpack.notification.domain;

// notifications.ref_type 컬럼 값 (VARCHAR(30), DB에 CHECK 제약 없음).
// 알림을 눌렀을 때 앱이 이동할 화면의 종류이고, ref_id가 그 대상의 ID다
public enum NotificationRefType {
	SCHEDULE,
	EXPENSE,
	SETTLEMENT_SHARE,
	POLL,
	TASK,
	TRIP
}
