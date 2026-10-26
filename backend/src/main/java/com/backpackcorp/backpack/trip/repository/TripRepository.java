package com.backpackcorp.backpack.trip.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.trip.domain.Trip;

public interface TripRepository extends JpaRepository<Trip, UUID> {

	// 초대 코드를 새로 뽑을 때 겹치는지 확인한다
	boolean existsByInviteCode(String inviteCode);

	Optional<Trip> findByInviteCode(String inviteCode);
}
