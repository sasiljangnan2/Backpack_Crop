package com.backpackcorp.backpack.user.dto;

// 가입·비밀번호 변경이 함께 쓰는 비밀번호 규칙: 영문과 숫자를 각각 1자 이상 (길이는 @Size로 8~64자)
public final class PasswordRule {

	public static final String REGEX = "^(?=.*[A-Za-z])(?=.*[0-9]).+$";
	public static final String MESSAGE = "비밀번호에는 영문과 숫자가 모두 들어가야 해요.";

	private PasswordRule() {
	}
}
