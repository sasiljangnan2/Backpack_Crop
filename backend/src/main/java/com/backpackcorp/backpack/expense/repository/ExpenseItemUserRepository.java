package com.backpackcorp.backpack.expense.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.expense.domain.ExpenseItemUser;
import com.backpackcorp.backpack.expense.domain.ExpenseItemUserId;

public interface ExpenseItemUserRepository extends JpaRepository<ExpenseItemUser, ExpenseItemUserId> {
}
