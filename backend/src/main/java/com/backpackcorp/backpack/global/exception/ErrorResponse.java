package com.backpackcorp.backpack.global.exception;

import java.time.Instant;
import java.util.Map;

// 모든 에러 응답의 바디. code는 항상 ErrorCode 이름이고, details는 필드별 유효성 검사 메시지
public record ErrorResponse(
	Instant timestamp,
	int status,
	String code,
	String message,
	Map<String, String> details
) {

	public static ErrorResponse of(ErrorCode errorCode) {
		return of(errorCode, Map.of());
	}

	public static ErrorResponse of(ErrorCode errorCode, Map<String, String> details) {
		return new ErrorResponse(Instant.now(), errorCode.getStatus().value(), errorCode.name(),
			errorCode.getMessage(), details);
	}

	// Spring MVC 표준 예외용. status에는 실제 HTTP 상태(415 등)를 그대로 담는다
	public static ErrorResponse ofStatus(int status) {
		ErrorCode errorCode = ErrorCode.fromStatus(status);
		return new ErrorResponse(Instant.now(), status, errorCode.name(), errorCode.getMessage(), Map.of());
	}
}
