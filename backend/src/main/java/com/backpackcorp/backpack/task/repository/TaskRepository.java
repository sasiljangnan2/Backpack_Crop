package com.backpackcorp.backpack.task.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.task.domain.Task;

public interface TaskRepository extends JpaRepository<Task, UUID> {
}
