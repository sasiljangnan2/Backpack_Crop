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

	// Auth · User
	// 이메일이 없는지 비밀번호가 틀렸는지 구분하지 않는다 (가입 여부를 알려 주지 않는다)
	INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않습니다."),
	TOO_MANY_LOGIN_ATTEMPTS(HttpStatus.TOO_MANY_REQUESTS, "로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요."),
	EMAIL_ALREADY_EXISTS(HttpStatus.CONFLICT, "이미 가입된 이메일입니다."),
	INVALID_PASSWORD(HttpStatus.BAD_REQUEST, "현재 비밀번호가 올바르지 않습니다."),
	USER_NOT_FOUND(HttpStatus.NOT_FOUND, "회원 정보를 찾을 수 없습니다."),

	// Trip
	NOT_TRIP_MEMBER(HttpStatus.FORBIDDEN, "이 여행의 멤버만 할 수 있습니다."),
	NOT_TRIP_HOST(HttpStatus.FORBIDDEN, "방장만 할 수 있습니다."),
	// 시안에서 초대 코드 6칸이 빨간 테두리로 바뀌는 경우
	INVITE_CODE_NOT_FOUND(HttpStatus.NOT_FOUND, "초대 코드를 다시 확인해 주세요."),
	TRIP_FULL(HttpStatus.CONFLICT, "여행 인원이 가득 찼습니다."),
	// 지출이 있는 여행의 통화를 바꾸면 저장된 환율·외화 금액과 어긋난다
	TRIP_CURRENCY_LOCKED(HttpStatus.CONFLICT, "지출이 있는 여행은 통화를 바꿀 수 없습니다."),
	// 기간을 줄이면 밖으로 밀려나는 일정이 있을 때. details에 개수를 담는다
	TRIP_PERIOD_CONFLICT(HttpStatus.CONFLICT, "변경할 기간 밖에 일정이 있습니다."),

	// Schedule
	SCHEDULE_NOT_FOUND(HttpStatus.NOT_FOUND, "일정을 찾을 수 없습니다."),
	INVALID_TIME_RANGE(HttpStatus.BAD_REQUEST, "종료 시간은 시작 시간보다 늦어야 합니다."),
	SCHEDULE_OUT_OF_TRIP(HttpStatus.BAD_REQUEST, "여행 기간 안의 날짜를 선택해 주세요."),
	// details에 겹친 일정(id · 제목 · 시간)을 담는다. 시안의 "겹친 일정 표시"에 쓴다
	SCHEDULE_OVERLAP(HttpStatus.CONFLICT, "다른 일정과 시간이 겹쳐요."),
	// 고정된 일정은 고정을 먼저 풀어야 바꾸거나 지울 수 있다
	SCHEDULE_LOCKED(HttpStatus.CONFLICT, "고정된 일정이에요. 고정을 먼저 풀어 주세요."),
	// 조회 후 다른 사람이 먼저 고쳤을 때. 앱은 다시 불러와 보여 준다
	VERSION_CONFLICT(HttpStatus.CONFLICT, "다른 사람이 먼저 수정했어요. 새로고침 후 다시 시도해 주세요."),

	// Exchange rate
	// 그 날짜와 이전 날짜 모두 환율이 없을 때. 앱은 원화 직접 입력(KRW)이나 직접 입력 환율(MANUAL)을 안내한다
	EXCHANGE_RATE_NOT_FOUND(HttpStatus.NOT_FOUND, "환율 정보를 찾을 수 없습니다."),

	// Expense
	// 금액·분담 규칙 위반. details에 어느 값이 문제인지 담는다 (예: "items[0].amountLocal")
	INVALID_EXPENSE(HttpStatus.BAD_REQUEST, "지출 내용을 다시 확인해 주세요."),
	PREPAID_RATE_NOT_SET(HttpStatus.BAD_REQUEST, "결제자의 선불 환율이 설정되어 있지 않습니다."),
	EXPENSE_NOT_FOUND(HttpStatus.NOT_FOUND, "지출을 찾을 수 없습니다."),
	// 결제자 · 작성자 · 방장만 고치거나 지울 수 있다
	NOT_EXPENSE_EDITOR(HttpStatus.FORBIDDEN, "결제자, 작성자, 방장만 수정할 수 있습니다."),

	// Settlement
	NOTHING_TO_SETTLE(HttpStatus.CONFLICT, "주고받을 돈이 없습니다."),
	SETTLEMENT_SHARE_NOT_FOUND(HttpStatus.NOT_FOUND, "공유한 정산을 찾을 수 없습니다."),

	// Budget
	BUDGET_ITEM_NOT_FOUND(HttpStatus.NOT_FOUND, "예산 항목을 찾을 수 없습니다."),

	// Task
	TASK_NOT_FOUND(HttpStatus.NOT_FOUND, "준비 업무를 찾을 수 없습니다."),
	// 함께 할(TEAM) 업무는 만든 사람 · 담당자 · 방장만 지울 수 있다
	NOT_TASK_OWNER(HttpStatus.FORBIDDEN, "업무를 만든 사람, 담당자, 방장만 지울 수 있습니다."),

	// Poll
	POLL_NOT_FOUND(HttpStatus.NOT_FOUND, "투표를 찾을 수 없습니다."),
	POLL_CLOSED(HttpStatus.CONFLICT, "마감된 투표입니다."),
	INVALID_POLL_OPTION(HttpStatus.BAD_REQUEST, "이 투표의 후보가 아닙니다."),
	// 마감·삭제는 만든 사람과 방장만 할 수 있다
	NOT_POLL_MANAGER(HttpStatus.FORBIDDEN, "투표를 만든 사람이나 방장만 할 수 있습니다."),

	// Notification
	NOTIFICATION_NOT_FOUND(HttpStatus.NOT_FOUND, "알림을 찾을 수 없습니다.");

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
