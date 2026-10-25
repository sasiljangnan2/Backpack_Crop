package com.backpackcorp.backpack.budget.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.budget.domain.BudgetItem;

public interface BudgetItemRepository extends JpaRepository<BudgetItem, UUID> {

	List<BudgetItem> findByTripIdOrderById(UUID tripId);

	Optional<BudgetItem> findByIdAndTripId(UUID id, UUID tripId);
}
