package com.backpackcorp.backpack.poll.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.poll.domain.PollVote;

public interface PollVoteRepository extends JpaRepository<PollVote, UUID> {
}
