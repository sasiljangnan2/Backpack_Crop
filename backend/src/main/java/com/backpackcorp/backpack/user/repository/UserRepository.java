package com.backpackcorp.backpack.user.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.user.domain.User;

public interface UserRepository extends JpaRepository<User, UUID> {
}
