package com.backpackcorp.backpack.expense.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import com.backpackcorp.backpack.global.entity.BaseTimeEntity;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "expenses")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Expense extends BaseTimeEntity {

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "trip_id", nullable = false)
	private Trip trip;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "payer_member_id", nullable = false)
	private TripMember payer;

	// payer와 다르면 대리 입력
	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "creator_member_id", nullable = false)
	private TripMember creator;

	// 가게명 등
	@Column(nullable = false, length = 100)
	private String title;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 20)
	private ExpenseCategory category;

	@Column(nullable = false)
	private LocalDate paidDate;

	// 여행 통화 금액. KRW 직접 입력이면 null
	@Column(precision = 15, scale = 2)
	private BigDecimal amountLocal;

	// KRW 모드면 amountLocal·appliedRate가 null, 그 외에는 둘 다 필수 (ck_expenses_krw_mode)
	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 10)
	private RateMode rateMode;

	// 저장 시점 스냅샷. KRW 모드면 null
	@Column(precision = 15, scale = 6)
	private BigDecimal appliedRate;

	// 실제 적용된 환율 날짜 (API 장애·주말 대비)
	private LocalDate rateDate;

	// 최종 원화
	@Column(nullable = false, precision = 15, scale = 0)
	private BigDecimal amountKrw;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 10)
	private SplitMethod splitMethod;

	// 낙관적 락
	@Version
	@Column(nullable = false)
	private int version;

	@Builder
	private Expense(Trip trip, TripMember payer, TripMember creator, String title,
		ExpenseCategory category,
		LocalDate paidDate, BigDecimal amountLocal, RateMode rateMode, BigDecimal appliedRate, LocalDate rateDate,
		BigDecimal amountKrw, SplitMethod splitMethod) {
		this.trip = trip;
		this.payer = payer;
		this.creator = creator;
		this.title = title;
		this.category = category;
		this.paidDate = paidDate;
		this.amountLocal = amountLocal;
		this.rateMode = rateMode;
		this.appliedRate = appliedRate;
		this.rateDate = rateDate;
		this.amountKrw = amountKrw;
		this.splitMethod = splitMethod;
	}

	// 수정은 전체 교체다. 작성자(creator)와 여행은 바뀌지 않는다
	public void replaceWith(Expense source) {
		this.payer = source.payer;
		this.title = source.title;
		this.category = source.category;
		this.paidDate = source.paidDate;
		this.amountLocal = source.amountLocal;
		this.rateMode = source.rateMode;
		this.appliedRate = source.appliedRate;
		this.rateDate = source.rateDate;
		this.amountKrw = source.amountKrw;
		this.splitMethod = source.splitMethod;
	}
}
