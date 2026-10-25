package com.backpackcorp.backpack.poll.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.poll.domain.PollVote;

public interface PollVoteRepository extends JpaRepository<PollVote, UUID> {

	@Query("""
		select v from PollVote v
		join fetch v.member m
		left join fetch m.user
		where v.poll.id in :pollIds
		order by m.joinedAt, m.id
		""")
	List<PollVote> findWithMemberByPollIds(@Param("pollIds") Collection<UUID> pollIds);

	Optional<PollVote> findByPollIdAndMemberId(UUID pollId, UUID memberId);
}
