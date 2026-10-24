package com.backpackcorp.backpack.poll.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.poll.domain.Poll;

public interface PollRepository extends JpaRepository<Poll, UUID> {
}
