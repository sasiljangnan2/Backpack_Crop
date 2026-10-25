package com.backpackcorp.backpack.notification.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record DeviceTokenRequest(
	@NotBlank(message = "FCM 토큰이 필요해요.")
	@Size(max = 255, message = "FCM 토큰이 너무 길어요.")
	String fcmToken
) {
}
