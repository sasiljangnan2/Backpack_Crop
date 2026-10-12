package com.backpackcorp.backpack.budget.domain;

import java.math.BigDecimal;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.global.entity.BaseCreatedEntity;
import com.backpackcorp.backpack.trip.domain.Trip;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
@Table(name = "budget_items")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class BudgetItem extends BaseCreatedEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "trip_id", nullable = false)
	private Trip trip;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 20)
	private ExpenseCategory category;

	@Column(nullable = false, length = 100)
	private String name;

	@Column(nullable = false, precision = 15, scale = 2)
	private BigDecimal amount;

	// KRW 또는 여행 통화
	@JdbcTypeCode(SqlTypes.CHAR)
	@Column(nullable = false, length = 3)
	private String currencyCode;

	@Builder
	private BudgetItem(Trip trip, ExpenseCategory category, String name, BigDecimal amount, String currencyCode) {
		this.trip = trip;
		this.category = category;
		this.name = name;
		this.amount = amount;
		this.currencyCode = currencyCode;
	}
}
