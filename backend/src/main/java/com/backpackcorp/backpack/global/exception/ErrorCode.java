package com.backpackcorp.backpack.global.exception;

import org.springframework.http.HttpStatus;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum ErrorCode {

	// Common
	BAD_REQUEST(HttpStatus.BAD_REQUEST, "잘못된 요청입니다."),
	VALIDATION_ERROR(HttpStatus.BAD_REQUEST, "요청 데이터 유효성 검사에 실패했습니다."),
	UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "인증이 필요합니다."),
	// 앱은 이 코드를 받으면 리프레시 토큰으로 재발급을 시도한다. 그 외 401은 다시 로그인해야 한다
	TOKEN_EXPIRED(HttpStatus.UNAUTHORIZED, "액세스 토큰이 만료되었습니다."),
	FORBIDDEN(HttpStatus.FORBIDDEN, "접근 권한이 없습니다."),
	NOT_FOUND(HttpStatus.NOT_FOUND, "요청한 리소스를 찾을 수 없습니다."),
	METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED, "지원하지 않는 HTTP 메서드입니다."),
	CONFLICT(HttpStatus.CONFLICT, "이미 존재하거나 현재 상태와 충돌하는 요청입니다."),
	// 업로드 크기 제한(spring.servlet.multipart)을 넘었을 때
	PAYLOAD_TOO_LARGE(HttpStatus.CONTENT_TOO_LARGE, "파일이 너무 큽니다."),
	INVALID_IMAGE(HttpStatus.BAD_REQUEST, "JPG 또는 PNG 이미지만 올릴 수 있습니다."),
	INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "서버 내부 오류가 발생했습니다."),

	// 도메인별 에러 코드는 아래에 추가 (예: USER_NOT_FOUND(HttpStatus.NOT_FOUND, "..."))

	// Trip
	NOT_TRIP_MEMBER(HttpStatus.FORBIDDEN, "이 여행의 멤버만 할 수 있습니다."),
	NOT_TRIP_HOST(HttpStatus.FORBIDDEN, "방장만 할 수 있습니다.");

	private final HttpStatus status;
	private final String message;

	// Spring MVC 표준 예외(잘못된 JSON, 405, 404 등)의 HTTP 상태에 대응하는 공통 코드.
	// 따로 정의하지 않은 4xx는 BAD_REQUEST, 그 외는 INTERNAL_SERVER_ERROR로 묶는다
	public static ErrorCode fromStatus(int status) {
		return switch (status) {
			case 401 -> UNAUTHORIZED;
			case 403 -> FORBIDDEN;
			case 404 -> NOT_FOUND;
			case 405 -> METHOD_NOT_ALLOWED;
			case 409 -> CONFLICT;
			case 413 -> PAYLOAD_TOO_LARGE;
			default -> status >= 400 && status < 500 ? BAD_REQUEST : INTERNAL_SERVER_ERROR;
		};
	}
}
