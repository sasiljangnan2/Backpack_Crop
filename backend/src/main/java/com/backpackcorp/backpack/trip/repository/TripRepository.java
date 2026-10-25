package com.backpackcorp.backpack.trip.repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.trip.domain.Trip;

public interface TripRepository extends JpaRepository<Trip, UUID> {

	Optional<Trip> findByInviteCode(String inviteCode);

	boolean existsByInviteCode(String inviteCode);

	// 환율 수집 대상: since 이후에 끝나는(또는 아직 진행 중인) 여행의 통화
	@Query("select distinct t.currencyCode from Trip t where t.endDate >= :since")
	List<String> findCurrenciesInUse(@Param("since") LocalDate since);
}
