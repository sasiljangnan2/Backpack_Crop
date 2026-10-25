package com.backpackcorp.backpack.settlement.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.settlement.domain.SettlementShare;

public interface SettlementShareRepository extends JpaRepository<SettlementShare, UUID> {

	// 최신순 (UUID v7)
	@Query("""
		select s from SettlementShare s
		join fetch s.sharedBy m
		left join fetch m.user
		where s.trip.id = :tripId
		order by s.id desc
		""")
	List<SettlementShare> findByTrip(@Param("tripId") UUID tripId);

	@Query("""
		select s from SettlementShare s
		join fetch s.sharedBy m
		left join fetch m.user
		where s.id = :id and s.trip.id = :tripId
		""")
	Optional<SettlementShare> findInTrip(@Param("id") UUID id, @Param("tripId") UUID tripId);
}
