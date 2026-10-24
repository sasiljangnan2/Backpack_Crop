package com.backpackcorp.backpack.expense.domain;

import java.io.Serializable;
import java.util.UUID;

import jakarta.persistence.Embeddable;

// expense_item_users 의 복합 PK (item_id, member_id)
@Embeddable
public record ExpenseItemUserId(UUID itemId, UUID memberId) implements Serializable {
}
