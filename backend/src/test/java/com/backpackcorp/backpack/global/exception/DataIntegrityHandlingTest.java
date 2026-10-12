package com.backpackcorp.backpack.global.exception;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.global.entity.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Table;

// 실제 DB가 낸 제약 위반이 Spring 예외로 번역된 뒤 핸들러에서 어떤 상태가 되는지 확인한다
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class DataIntegrityHandlingTest {

	@Autowired
	private EntityManager entityManager;
	// 리포지토리가 예외를 번역할 때 쓰는 것과 같은 번역기
	@Autowired
	private LocalContainerEntityManagerFactoryBean exceptionTranslator;

	private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

	@Test
	void 유니크_컬럼에_같은_값을_저장하면_409다() {
		entityManager.persist(new UniqueSample("same"));
		entityManager.persist(new UniqueSample("same"));

		DataIntegrityViolationException e = translated(catchThrowableOfType(RuntimeException.class,
			entityManager::flush));

		assertThat(handler.handleDataIntegrity(e).getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
	}

	@Test
	void 중복이_아닌_제약_위반은_500이다() {
		DataIntegrityViolationException e = translated(catchThrowableOfType(RuntimeException.class, () -> {
			entityManager.persist(new UniqueSample(null));
			entityManager.flush();
		}));

		assertThat(handler.handleDataIntegrity(e).getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
	}

	private DataIntegrityViolationException translated(RuntimeException e) {
		return (DataIntegrityViolationException) exceptionTranslator.translateExceptionIfPossible(e);
	}

	@Entity
	@Table(name = "data_integrity_test_sample")
	static class UniqueSample extends BaseEntity {

		@Column(nullable = false, unique = true)
		private String code;

		protected UniqueSample() {
		}

		UniqueSample(String code) {
			this.code = code;
		}
	}
}
