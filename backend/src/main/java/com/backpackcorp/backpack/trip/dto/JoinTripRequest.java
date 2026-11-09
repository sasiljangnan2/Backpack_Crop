package com.backpackcorp.backpack.trip.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

// 대소문자·앞뒤 공백·하이픈은 서버가 정리한다
public record JoinTripRequest(
	@NotBlank(message = "초대 코드를 입력해 주세요.")
	@Size(max = 20, message = "초대 코드를 다시 확인해 주세요.")
	String inviteCode
) {
}
