package com.backpackcorp.backpack.global.exception;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.MediaType;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

class GlobalExceptionHandlerTest {

	private final MockMvc mockMvc = MockMvcBuilders.standaloneSetup(new TestController())
		.setControllerAdvice(new GlobalExceptionHandler())
		.build();

	@Test
	void baseException은_ErrorCode의_상태와_코드로_응답한다() throws Exception {
		mockMvc.perform(get("/base"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
			.andExpect(jsonPath("$.status").value(400));
	}

	@Test
	void 유효성_검사_실패는_필드별_메시지를_담는다() throws Exception {
		mockMvc.perform(post("/valid").contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
			.andExpect(jsonPath("$.details.name").exists());
	}

	@Test
	void 잘못된_JSON은_500이_아니라_400이다() throws Exception {
		mockMvc.perform(post("/valid").contentType(MediaType.APPLICATION_JSON).content("{"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("BAD_REQUEST"));
	}

	@Test
	void 예상치_못한_예외는_내부_메시지를_노출하지_않는다() throws Exception {
		mockMvc.perform(get("/unexpected"))
			.andExpect(status().isInternalServerError())
			.andExpect(jsonPath("$.code").value("INTERNAL_SERVER_ERROR"))
			.andExpect(jsonPath("$.message").value(ErrorCode.INTERNAL_SERVER_ERROR.getMessage()));
	}

	@Test
	void 파라미터_제약_실패는_파라미터_이름으로_메시지를_담는다() throws Exception {
		mockMvc.perform(get("/param").param("size", "0"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
			.andExpect(jsonPath("$.details.size").exists());
	}

	@Test
	void 인증_예외는_401이다() throws Exception {
		mockMvc.perform(get("/unauthenticated"))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
	}

	@Test
	void 권한_예외는_403이다() throws Exception {
		mockMvc.perform(get("/denied"))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("FORBIDDEN"));
	}

	@Test
	void 유니크_중복은_409이고_제약_이름을_노출하지_않는다() throws Exception {
		mockMvc.perform(get("/duplicate"))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("CONFLICT"))
			.andExpect(jsonPath("$.message").value(ErrorCode.CONFLICT.getMessage()));
	}

	@Test
	void 동시_수정_충돌은_500이_아니라_409다() throws Exception {
		mockMvc.perform(get("/stale"))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("CONFLICT"))
			.andExpect(jsonPath("$.message").value(ErrorCode.CONFLICT.getMessage()));
	}

	@Test
	void 중복이_아닌_DB_제약_위반은_409가_아니라_500이다() throws Exception {
		mockMvc.perform(get("/check-violation"))
			.andExpect(status().isInternalServerError())
			.andExpect(jsonPath("$.code").value("INTERNAL_SERVER_ERROR"))
			.andExpect(jsonPath("$.message").value(ErrorCode.INTERNAL_SERVER_ERROR.getMessage()));
	}

	@Test
	void 클래스_단위_제약_실패는_객체명으로_메시지를_담는다() throws Exception {
		mockMvc.perform(post("/period").contentType(MediaType.APPLICATION_JSON).content("{\"start\":2,\"end\":1}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
			.andExpect(jsonPath("$.details.period").value("종료는 시작 이후여야 합니다"));
	}

	@Test
	void 표준_예외도_ErrorCode의_코드와_메시지로_응답하고_status는_실제_상태다() throws Exception {
		mockMvc.perform(post("/valid").contentType(MediaType.TEXT_PLAIN).content("x"))
			.andExpect(status().isUnsupportedMediaType())
			.andExpect(jsonPath("$.status").value(415))
			.andExpect(jsonPath("$.code").value("BAD_REQUEST"))
			.andExpect(jsonPath("$.message").value(ErrorCode.BAD_REQUEST.getMessage()));

		mockMvc.perform(post("/base"))
			.andExpect(status().isMethodNotAllowed())
			.andExpect(jsonPath("$.code").value("METHOD_NOT_ALLOWED"));
	}

	record Request(@NotBlank String name) {
	}

	@ValidPeriod
	record Period(int start, int end) {
	}

	@Target(ElementType.TYPE)
	@Retention(RetentionPolicy.RUNTIME)
	@Constraint(validatedBy = PeriodValidator.class)
	@interface ValidPeriod {

		String message() default "종료는 시작 이후여야 합니다";

		Class<?>[] groups() default {};

		Class<? extends Payload>[] payload() default {};
	}

	// 검증기는 public 기본 생성자가 있어야 Hibernate Validator가 만들 수 있다
	public static class PeriodValidator implements ConstraintValidator<ValidPeriod, Period> {

		@Override
		public boolean isValid(Period period, ConstraintValidatorContext context) {
			return period.end() >= period.start();
		}
	}

	@RestController
	static class TestController {

		@GetMapping("/base")
		void base() {
			throw new BaseException(ErrorCode.VALIDATION_ERROR);
		}

		@PostMapping("/valid")
		void valid(@Valid @RequestBody Request request) {
		}

		@GetMapping("/param")
		void param(@RequestParam @Min(1) int size) {
		}

		@GetMapping("/unauthenticated")
		void unauthenticated() {
			throw new BadCredentialsException("bad credentials");
		}

		@GetMapping("/denied")
		void denied() {
			throw new AccessDeniedException("denied");
		}

		@GetMapping("/duplicate")
		void duplicate() {
			throw new DuplicateKeyException("Duplicate entry 'a@b.c' for key 'uk_users_email'");
		}

		@GetMapping("/check-violation")
		void checkViolation() {
			throw new DataIntegrityViolationException("Check constraint 'ck_trips_period' is violated.");
		}

		@GetMapping("/stale")
		void stale() {
			throw new ObjectOptimisticLockingFailureException("Schedule", "id");
		}

		@PostMapping("/period")
		void period(@Valid @RequestBody Period period) {
		}

		@GetMapping("/unexpected")
		void unexpected() {
			throw new IllegalStateException("db password is hunter2");
		}
	}
}
