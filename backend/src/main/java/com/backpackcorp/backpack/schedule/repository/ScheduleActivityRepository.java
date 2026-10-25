package com.backpackcorp.backpack.schedule.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.schedule.domain.ScheduleActivity;

public interface ScheduleActivityRepository extends JpaRepository<ScheduleActivity, UUID> {

	Optional<ScheduleActivity> findByScheduleId(UUID scheduleId);

	List<ScheduleActivity> findByScheduleIdIn(Collection<UUID> scheduleIds);
}
