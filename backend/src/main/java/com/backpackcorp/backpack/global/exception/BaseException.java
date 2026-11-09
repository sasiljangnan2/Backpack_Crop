package com.backpackcorp.backpack.global.exception;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

import lombok.Getter;

@Getter
public class BaseException extends RuntimeException {

	private final ErrorCode errorCode;
	// 앱이 화면에 바로 보여 줄 수 있는 추가 정보. ErrorResponse.details로 나간다 (예: 문제가 된 필드)
	private final Map<String, String> details;

	public BaseException(ErrorCode errorCode) {
		this(errorCode, Map.of());
	}

	public BaseException(ErrorCode errorCode, Map<String, String> details) {
		super(errorCode.getMessage());
		this.errorCode = errorCode;
		// 넣은 순서를 지켜서 내려준다
		this.details = Collections.unmodifiableMap(new LinkedHashMap<>(details));
	}

	public static BaseException of(ErrorCode errorCode, String field, String message) {
		return new BaseException(errorCode, Map.of(field, message));
	}
}
