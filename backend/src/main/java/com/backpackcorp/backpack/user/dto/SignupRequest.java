package com.backpackcorp.backpack.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record SignupRequest(
	@NotBlank(message = "이메일을 입력해 주세요.")
	@Email(message = "이메일 형식이 올바르지 않아요.")
	@Size(max = 255, message = "이메일이 너무 길어요.")
	String email,

	@NotBlank(message = "비밀번호를 입력해 주세요.")
	@Size(min = 8, max = 64, message = "비밀번호는 8~64자로 입력해 주세요.")
	@Pattern(regexp = PasswordRule.REGEX, message = PasswordRule.MESSAGE)
	String password,

	@NotBlank(message = "이름을 입력해 주세요.")
	@Size(max = 20, message = "이름은 20자 이하로 입력해 주세요.")
	String name
) {
}
