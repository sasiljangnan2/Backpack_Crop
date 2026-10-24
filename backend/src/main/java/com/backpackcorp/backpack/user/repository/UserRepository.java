package com.backpackcorp.backpack.user.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.user.domain.User;

// save · findById 같은 기본 메서드는 JpaRepository가 제공한다.
// 그 밖의 조회는 메서드 이름만 규칙대로 지으면 Spring Data JPA가 SQL을 만들어 준다
public interface UserRepository extends JpaRepository<User, UUID> {

	// SELECT 1 FROM users WHERE email = ? 와 같다. 탈퇴 회원도 이메일 컬럼이 UNIQUE라 함께 확인한다
	boolean existsByEmail(String email);
}
