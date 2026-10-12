package com.backpackcorp.backpack.budget.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.springframework.data.annotation.CreatedDate;

import com.backpackcorp.backpack.global.entity.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(
	name = "exchange_rates",
	uniqueConstraints = @UniqueConstraint(name = "uk_exchange_rates_code_date", columnNames = {"currency_code", "rate_date"})
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ExchangeRate extends BaseEntity {

	@JdbcTypeCode(SqlTypes.CHAR)
	@Column(nullable = false, length = 3)
	private String currencyCode;

	@Column(nullable = false)
	private LocalDate rateDate;

	// 1단위 기준 (JPY·IDR처럼 100단위로 고시되는 값은 100으로 나눠 저장)
	@Column(nullable = false, precision = 15, scale = 6)
	private BigDecimal rateToKrw;

	@CreatedDate
	@Column(nullable = false, updatable = false)
	private Instant fetchedAt;

	@Builder
	private ExchangeRate(String currencyCode, LocalDate rateDate, BigDecimal rateToKrw) {
		this.currencyCode = currencyCode;
		this.rateDate = rateDate;
		this.rateToKrw = rateToKrw;
	}
}
