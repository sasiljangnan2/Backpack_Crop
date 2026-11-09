package com.backpackcorp.backpack.trip.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.dto.TripMemberCountDto;

public interface TripMemberRepository extends JpaRepository<TripMember, UUID> {

	// 나간 멤버(left_at이 있는 행)는 제외한다
	Optional<TripMember> findByTripIdAndUserIdAndLeftAtIsNull(UUID tripId, UUID userId);

	// 나간 멤버도 찾는다 (다시 참여할 때 같은 행을 되살린다)
	Optional<TripMember> findByTripIdAndUserId(UUID tripId, UUID userId);

	// 나간 멤버도 포함한다. 지출·정산에는 나간 멤버의 기록도 남아 있어야 한다. 참여한 순서
	@Query("select m from TripMember m left join fetch m.user where m.trip.id = :tripId order by m.joinedAt, m.id")
	List<TripMember> findAllWithUserByTripId(@Param("tripId") UUID tripId);

	// 내 여행 목록용: 내가 현재 멤버인 행과 그 여행
	@Query("select m from TripMember m join fetch m.trip where m.user.id = :userId and m.leftAt is null")
	List<TripMember> findActiveWithTripByUserId(@Param("userId") UUID userId);

	@Query("""
		select new com.backpackcorp.backpack.trip.dto.TripMemberCountDto(m.trip.id, count(m))
		from TripMember m
		where m.trip.id in :tripIds and m.leftAt is null
		group by m.trip.id
		""")
	List<TripMemberCountDto> countActiveByTripIds(@Param("tripIds") Collection<UUID> tripIds);

	long countByTripIdAndLeftAtIsNull(UUID tripId);
}
