package com.backpackcorp.backpack.schedule.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.schedule.domain.Schedule;

public interface ScheduleRepository extends JpaRepository<Schedule, UUID> {
}
