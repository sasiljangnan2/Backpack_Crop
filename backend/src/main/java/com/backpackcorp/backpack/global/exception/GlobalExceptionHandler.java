package com.backpackcorp.backpack.global.exception;

import java.util.LinkedHashMap;
import java.util.Map;

import org.hibernate.exception.ConstraintViolationException;
import org.hibernate.exception.ConstraintViolationException.ConstraintKind;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.validation.Errors;
import org.springframework.validation.method.ParameterErrors;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import lombok.extern.slf4j.Slf4j;

// 잘못된 JSON, 405, 404 같은 Spring MVC 표준 예외는 부모 클래스가 상태 코드를 정하고,
// 여기서는 바디만 ErrorResponse 형식으로 맞춘다
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

	@ExceptionHandler(BaseException.class)
	public ResponseEntity<ErrorResponse> handleBaseException(BaseException e) {
		ErrorCode errorCode = e.getErrorCode();
		log.warn("비즈니스 예외: code={}, message={}, details={}", errorCode, e.getMessage(), e.getDetails());
		return ResponseEntity.status(errorCode.getStatus()).body(ErrorResponse.of(errorCode, e.getDetails()));
	}

	// 401 - SecurityConfig의 AuthenticationEntryPoint도 이쪽으로 위임한다
	@ExceptionHandler(AuthenticationException.class)
	public ResponseEntity<ErrorResponse> handleAuthentication(AuthenticationException e) {
		return toResponse(isExpiredToken(e) ? ErrorCode.TOKEN_EXPIRED : ErrorCode.UNAUTHORIZED);
	}

	// 403 - SecurityConfig의 AccessDeniedHandler도 이쪽으로 위임한다
	@ExceptionHandler(AccessDeniedException.class)
	public ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException e) {
		return toResponse(ErrorCode.FORBIDDEN);
	}

	// DB 제약 위반. 유니크 중복만 409이고, 나머지(NOT NULL·FK·CHECK·길이 초과)는
	// 앱 검증이 놓친 것이므로 500으로 남겨 로그에 드러낸다
	@ExceptionHandler(DataIntegrityViolationException.class)
	public ResponseEntity<ErrorResponse> handleDataIntegrity(DataIntegrityViolationException e) {
		if (!isDuplicateKey(e)) {
			return handleUnexpected(e);
		}
		// 제약 이름이 담긴 원본 메시지는 로그에만 남긴다
		log.warn("유니크 제약 위반: {}", e.getMostSpecificCause().getMessage());
		return toResponse(ErrorCode.CONFLICT);
	}

	// 409 - @Version이 있는 엔티티(일정, 지출)를 두 사람이 동시에 고쳐 나중 쪽이 밀려난 경우.
	// 앱은 최신 내용을 다시 불러와 보여 준다
	@ExceptionHandler(OptimisticLockingFailureException.class)
	public ResponseEntity<ErrorResponse> handleOptimisticLock(OptimisticLockingFailureException e) {
		log.warn("동시 수정 충돌: {}", e.getMessage());
		return toResponse(ErrorCode.CONFLICT);
	}

	// 500 - 그 외 모든 예외. 내부 메시지는 응답에 노출하지 않는다
	@ExceptionHandler(Exception.class)
	public ResponseEntity<ErrorResponse> handleUnexpected(Exception e) {
		log.error("예상치 못한 오류", e);
		return toResponse(ErrorCode.INTERNAL_SERVER_ERROR);
	}

	// 400 - @RequestBody @Valid 실패 → 필드별 메시지
	@Override
	protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException ex,
		HttpHeaders headers, HttpStatusCode status, WebRequest request) {
		Map<String, String> details = new LinkedHashMap<>();
		addErrors(details, ex);
		return handleExceptionInternal(ex, ErrorResponse.of(ErrorCode.VALIDATION_ERROR, details), headers, status,
			request);
	}

	// 400 - @RequestParam, @PathVariable 등 파라미터에 직접 건 제약 실패 → 파라미터별 메시지
	@Override
	protected ResponseEntity<Object> handleHandlerMethodValidationException(HandlerMethodValidationException ex,
		HttpHeaders headers, HttpStatusCode status, WebRequest request) {
		Map<String, String> details = new LinkedHashMap<>();
		ex.getParameterValidationResults().forEach(result -> {
			if (result instanceof ParameterErrors errors) {
				addErrors(details, errors);
				return;
			}
			String name = result.getMethodParameter().getParameterName();
			result.getResolvableErrors().forEach(error -> details.putIfAbsent(name, error.getDefaultMessage()));
		});
		return handleExceptionInternal(ex, ErrorResponse.of(ErrorCode.VALIDATION_ERROR, details), headers, status,
			request);
	}

	@Override
	protected ResponseEntity<Object> handleExceptionInternal(Exception ex, Object body, HttpHeaders headers,
		HttpStatusCode statusCode, WebRequest request) {
		if (!(body instanceof ErrorResponse)) {
			body = ErrorResponse.ofStatus(statusCode.value());
		}
		return super.handleExceptionInternal(ex, body, headers, statusCode, request);
	}

	// 필드 오류는 필드명으로, 클래스 단위(교차 필드) 제약 오류는 객체명으로 담는다
	private static void addErrors(Map<String, String> details, Errors errors) {
		errors.getFieldErrors().forEach(error -> details.putIfAbsent(error.getField(), error.getDefaultMessage()));
		errors.getGlobalErrors()
			.forEach(error -> details.putIfAbsent(error.getObjectName(), error.getDefaultMessage()));
	}

	// JPA 경로는 Hibernate의 ConstraintViolationException(UNIQUE)을 원인으로 담아 오고,
	// JDBC 경로는 DuplicateKeyException으로 온다
	private static boolean isDuplicateKey(DataIntegrityViolationException e) {
		return e instanceof DuplicateKeyException
			|| (e.getCause() instanceof ConstraintViolationException cause && cause.getKind() == ConstraintKind.UNIQUE);
	}

	// 만료 여부는 SecurityConfig의 JwtDecoder 검증기가 남긴 오류 코드로 구분한다
	private static boolean isExpiredToken(AuthenticationException e) {
		return e.getCause() instanceof JwtValidationException invalid
			&& invalid.getErrors().stream()
				.anyMatch(error -> ErrorCode.TOKEN_EXPIRED.name().equals(error.getErrorCode()));
	}

	private static ResponseEntity<ErrorResponse> toResponse(ErrorCode errorCode) {
		return ResponseEntity.status(errorCode.getStatus()).body(ErrorResponse.of(errorCode));
	}
}
