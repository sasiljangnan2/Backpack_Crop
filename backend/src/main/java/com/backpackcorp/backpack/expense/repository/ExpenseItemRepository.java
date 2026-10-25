package com.backpackcorp.backpack.expense.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.expense.domain.ExpenseItem;

public interface ExpenseItemRepository extends JpaRepository<ExpenseItem, UUID> {

	List<ExpenseItem> findByExpenseIdOrderBySortOrder(UUID expenseId);

	// 수정·삭제 때 항목을 한 번에 지운다. 분담 행(expense_item_users)을 먼저 지워야 한다
	@Modifying(flushAutomatically = true, clearAutomatically = true)
	@Query("delete from ExpenseItem i where i.expense.id = :expenseId")
	void deleteByExpenseId(@Param("expenseId") UUID expenseId);
}
