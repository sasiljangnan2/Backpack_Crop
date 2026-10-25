package com.backpackcorp.backpack.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PasswordChangeRequest(
	@NotBlank(message = "현재 비밀번호를 입력해 주세요.")
	String currentPassword,

	@NotBlank(message = "새 비밀번호를 입력해 주세요.")
	@Size(min = 8, max = 64, message = "비밀번호는 8~64자로 입력해 주세요.")
	@Pattern(regexp = PasswordRule.REGEX, message = PasswordRule.MESSAGE)
	String newPassword
) {
}
