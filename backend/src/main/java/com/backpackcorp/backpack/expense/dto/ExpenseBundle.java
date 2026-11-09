package com.backpackcorp.backpack.expense.dto;

import java.util.List;

import com.backpackcorp.backpack.expense.domain.Expense;
import com.backpackcorp.backpack.expense.domain.ExpenseItem;
import com.backpackcorp.backpack.expense.domain.ExpenseItemUser;

// 지출 한 건과 그 항목·분담 (계층 간 전달용). 미리보기에서는 저장하지 않은 엔티티를 담는다 (id가 null)
public record ExpenseBundle(
	Expense expense,
	List<ItemBundle> items
) {

	public record ItemBundle(
		ExpenseItem item,
		List<ExpenseItemUser> shares
	) {
	}
}
