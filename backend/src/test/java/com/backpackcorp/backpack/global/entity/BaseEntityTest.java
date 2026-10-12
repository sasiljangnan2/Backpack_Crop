package com.backpackcorp.backpack.global.entity;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import jakarta.persistence.Entity;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Table;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class BaseEntityTest {

	@Autowired
	private EntityManager entityManager;

	@Test
	void 저장하면_UUID_v7_id와_생성_수정_시각이_채워진다() {
		Sample sample = new Sample();

		entityManager.persist(sample);
		entityManager.flush();

		assertThat(sample.getId()).isNotNull();
		assertThat(sample.getId().version()).isEqualTo(7);
		assertThat(sample.getCreatedAt()).isNotNull();
		assertThat(sample.getUpdatedAt()).isNotNull();
	}

	@Entity
	@Table(name = "base_entity_test_sample")
	static class Sample extends BaseTimeEntity {
	}
}
