package com.backpackcorp.backpack.user.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.user.domain.User;

// save · findById 같은 기본 메서드는 JpaRepository가 제공한다.
// 그 밖의 조회는 메서드 이름만 규칙대로 지으면 Spring Data JPA가 SQL을 만들어 준다
public interface UserRepository extends JpaRepository<User, UUID> {

	// SELECT 1 FROM users WHERE email = ? 와 같다. 탈퇴 회원도 이메일 컬럼이 UNIQUE라 함께 확인한다
	boolean existsByEmail(String email);

	// SELECT * FROM users WHERE email = ? AND deleted_at IS NULL 과 같다.
	// 탈퇴 회원은 찾지 않으므로 로그인할 수 없다. 없을 수도 있어서 Optional로 받는다
	Optional<User> findByEmailAndDeletedAtIsNull(String email);

	// 리프레시 토큰에서 꺼낸 ID로 찾는다. 탈퇴 회원은 찾지 않으므로 재발급할 수 없다
	Optional<User> findByIdAndDeletedAtIsNull(UUID id);
}
