package com.backpackcorp.backpack.expense.domain;

import java.math.BigDecimal;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import com.backpackcorp.backpack.global.entity.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "expense_items")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ExpenseItem extends BaseEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "expense_id", nullable = false)
	private Expense expense;

	// EQUAL이면 항목 1개(총액)
	@Column(nullable = false, length = 100)
	private String name;

	@Column(precision = 15, scale = 2)
	private BigDecimal amountLocal;

	@Column(nullable = false, precision = 15, scale = 0)
	private BigDecimal amountKrw;

	@JdbcTypeCode(SqlTypes.SMALLINT)
	@Column(nullable = false)
	private int sortOrder;

	@Builder
	private ExpenseItem(Expense expense, String name, BigDecimal amountLocal, BigDecimal amountKrw, int sortOrder) {
		this.expense = expense;
		this.name = name;
		this.amountLocal = amountLocal;
		this.amountKrw = amountKrw;
		this.sortOrder = sortOrder;
	}
}
