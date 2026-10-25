package com.backpackcorp.backpack.notification.dto;

import java.util.Map;
import java.util.Set;
import java.util.UUID;

// 커밋 뒤 보낼 푸시 한 건 (계층 간 전달용). data는 앱이 알림을 눌렀을 때 이동할 화면 정보다
public record PushRequest(
	Set<UUID> userIds,
	String title,
	String body,
	Map<String, String> data
) {
}
