package com.backpackcorp.backpack.notification.controller;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.dto.SliceCursorPageResponse;
import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.notification.dto.DeviceTokenRequest;
import com.backpackcorp.backpack.notification.dto.NotificationResponse;
import com.backpackcorp.backpack.notification.service.NotificationService;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
public class NotificationController {

	private final NotificationService notificationService;

	// 알림함 (최신순, 커서)
	@GetMapping("/api/notifications")
	public SliceCursorPageResponse<NotificationResponse> getNotifications(
		@AuthenticationPrincipal BackpackUserDetails user,
		@RequestParam(required = false) UUID cursor,
		@RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
		return notificationService.getNotifications(BackpackUserDetails.requireId(user), cursor, size);
	}

	// 앱 아이콘·종 모양 배지용
	@GetMapping("/api/notifications/unread-count")
	public Map<String, Long> countUnread(@AuthenticationPrincipal BackpackUserDetails user) {
		return Map.of("count", notificationService.countUnread(BackpackUserDetails.requireId(user)));
	}

	@PatchMapping("/api/notifications/{notificationId}/read")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void markRead(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID notificationId) {
		notificationService.markRead(BackpackUserDetails.requireId(user), notificationId);
	}

	@PatchMapping("/api/notifications/read-all")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void markAllRead(@AuthenticationPrincipal BackpackUserDetails user) {
		notificationService.markAllRead(BackpackUserDetails.requireId(user));
	}

	@PutMapping("/api/device-tokens")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void registerDeviceToken(@AuthenticationPrincipal BackpackUserDetails user,
		@Valid @RequestBody DeviceTokenRequest request) {
		notificationService.registerDeviceToken(BackpackUserDetails.requireId(user), request.fcmToken());
	}

	@DeleteMapping("/api/device-tokens")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void removeDeviceToken(@AuthenticationPrincipal BackpackUserDetails user,
		@Valid @RequestBody DeviceTokenRequest request) {
		notificationService.removeDeviceToken(BackpackUserDetails.requireId(user), request.fcmToken());
	}
}
