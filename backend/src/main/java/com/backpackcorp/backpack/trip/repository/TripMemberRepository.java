package com.backpackcorp.backpack.trip.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.trip.domain.TripMember;

public interface TripMemberRepository extends JpaRepository<TripMember, UUID> {

	// 나간 멤버(left_at이 있는 행)는 제외한다
	Optional<TripMember> findByTripIdAndUserIdAndLeftAtIsNull(UUID tripId, UUID userId);

	// 나간 멤버도 찾는다. 재참여할 때 새 행을 만들지 않고 left_at만 지운다 (trip_id + user_id가 UNIQUE)
	Optional<TripMember> findByTripIdAndUserId(UUID tripId, UUID userId);

	// 내 여행 목록. trip을 함께 읽어 여행마다 조회가 다시 나가지 않게 한다
	@EntityGraph(attributePaths = "trip")
	List<TripMember> findByUserIdAndLeftAtIsNullOrderByTripStartDateDesc(UUID userId);

	long countByTripIdAndLeftAtIsNull(UUID tripId);

	// 멤버 목록. 이름을 쓰려고 user를 함께 읽는다
	@EntityGraph(attributePaths = "user")
	List<TripMember> findByTripIdAndLeftAtIsNullOrderByJoinedAt(UUID tripId);
}
