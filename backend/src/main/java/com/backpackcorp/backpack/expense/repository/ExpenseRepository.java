package com.backpackcorp.backpack.expense.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.expense.domain.Expense;

public interface ExpenseRepository extends JpaRepository<Expense, UUID> {
}
