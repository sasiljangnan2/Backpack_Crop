package com.backpackcorp.backpack.expense.domain;

// expenses.category 와 budget_items.category 가 함께 쓰는 값 (VARCHAR(20), DB에 CHECK 제약 없음)
public enum ExpenseCategory {
	FOOD,
	LODGING,
	TRANSPORT,
	ACTIVITY,
	SHOPPING,
	ETC
}
