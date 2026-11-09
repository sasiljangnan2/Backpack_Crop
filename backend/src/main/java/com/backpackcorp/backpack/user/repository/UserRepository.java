package com.backpackcorp.backpack.user.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.user.domain.User;

public interface UserRepository extends JpaRepository<User, UUID> {

	// 이메일은 소문자로 바꿔 저장한다. 탈퇴 회원은 이메일이 익명화되어 있어 걸리지 않는다
	Optional<User> findByEmail(String email);

	boolean existsByEmail(String email);
}
