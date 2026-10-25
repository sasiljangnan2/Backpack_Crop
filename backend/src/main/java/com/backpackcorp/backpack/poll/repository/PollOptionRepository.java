package com.backpackcorp.backpack.poll.repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.poll.domain.PollOption;

public interface PollOptionRepository extends JpaRepository<PollOption, UUID> {

	List<PollOption> findByPollIdInOrderBySortOrder(Collection<UUID> pollIds);
}
