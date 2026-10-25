package com.backpackcorp.backpack.poll.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.poll.domain.Poll;

public interface PollRepository extends JpaRepository<Poll, UUID> {

	// 최신순 (UUID v7)
	@Query("""
		select p from Poll p
		join fetch p.creator c
		left join fetch c.user
		where p.trip.id = :tripId
		order by p.id desc
		""")
	List<Poll> findByTrip(@Param("tripId") UUID tripId);

	@Query("""
		select p from Poll p
		join fetch p.creator c
		left join fetch c.user
		where p.id = :id and p.trip.id = :tripId
		""")
	Optional<Poll> findInTrip(@Param("id") UUID id, @Param("tripId") UUID tripId);
}
