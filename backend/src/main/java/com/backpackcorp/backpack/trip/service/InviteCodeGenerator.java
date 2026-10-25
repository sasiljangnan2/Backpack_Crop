package com.backpackcorp.backpack.trip.service;

import java.security.SecureRandom;
import java.util.Locale;

import org.springframework.stereotype.Component;

// 초대 코드: 대문자 + 숫자 8자리. 손으로 옮겨 적을 때 헷갈리는 0 O 1 I는 쓰지 않는다.
// 32글자에서 8자리를 뽑으므로 경우의 수는 약 1조(2^40)라 무작위로 맞히기 어렵다
@Component
public class InviteCodeGenerator {

	static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
	public static final int LENGTH = 8;
	private static final SecureRandom RANDOM = new SecureRandom();

	public String generate() {
		StringBuilder code = new StringBuilder(LENGTH);
		for (int i = 0; i < LENGTH; i++) {
			code.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
		}
		return code.toString();
	}

	// 사용자가 입력한 코드를 저장 형식으로 맞춘다: 공백·하이픈 제거, 대문자
	public static String normalize(String input) {
		StringBuilder code = new StringBuilder();
		for (char c : input.toCharArray()) {
			if (c != ' ' && c != '-' && !Character.isWhitespace(c)) {
				code.append(c);
			}
		}
		return code.toString().toUpperCase(Locale.ROOT);
	}
}
