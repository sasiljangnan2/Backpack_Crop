package com.backpackcorp.backpack.expense.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.expense.domain.ExpenseItem;

public interface ExpenseItemRepository extends JpaRepository<ExpenseItem, UUID> {
}
