package com.backpackcorp.backpack.trip.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.trip.domain.TripMember;

public interface TripMemberRepository extends JpaRepository<TripMember, UUID> {

	// 나간 멤버(left_at이 있는 행)는 제외한다
	Optional<TripMember> findByTripIdAndUserIdAndLeftAtIsNull(UUID tripId, UUID userId);
}
