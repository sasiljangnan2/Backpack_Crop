package com.backpackcorp.backpack.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UserUpdateRequest(
	@NotBlank(message = "이름을 입력해 주세요.")
	@Size(max = 20, message = "이름은 20자 이하로 입력해 주세요.")
	String name
) {
}
