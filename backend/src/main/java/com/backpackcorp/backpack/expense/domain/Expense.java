package com.backpackcorp.backpack.expense.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import com.backpackcorp.backpack.global.entity.BaseTimeEntity;
import com.backpackcorp.backpack.schedule.domain.Schedule;
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

	// 예약 결제처럼 일정과 이어진 지출. 일정을 지워도 지출은 남는다 (BP-SC-003)
	@ManyToOne(fetch = FetchType.LAZY)
	@OnDelete(action = OnDeleteAction.SET_NULL)
	@JoinColumn(name = "schedule_id")
	private Schedule schedule;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "payer_member_id", nullable = false)
	private TripMember payer;

	// 공금에서 낸 지출. payer는 입력한 사람이고 정산에서 낸 돈으로 치지 않는다
	@Column(nullable = false)
	private boolean paidFromFund;

	// payer와 다르면 대리 입력
	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	@JoinColumn(name = "creator_member_id", nullable = false)
	private TripMember creator;

	// 가게명 등
	@Column(nullable = false, length = 100)
	private String title;

	// 외국어 영수증에서 읽은 가게 이름의 한국어 번역. 없으면 null
	@Column(length = 100)
	private String titleKo;

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
	private Expense(Trip trip, Schedule schedule, TripMember payer, boolean paidFromFund, TripMember creator,
		String title, String titleKo,
		ExpenseCategory category,
		LocalDate paidDate, BigDecimal amountLocal, RateMode rateMode, BigDecimal appliedRate, LocalDate rateDate,
		BigDecimal amountKrw, SplitMethod splitMethod) {
		this.trip = trip;
		this.schedule = schedule;
		this.payer = payer;
		this.paidFromFund = paidFromFund;
		this.creator = creator;
		this.title = title;
		this.titleKo = titleKo;
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
		this.schedule = source.schedule;
		this.payer = source.payer;
		this.paidFromFund = source.paidFromFund;
		this.title = source.title;
		this.titleKo = source.titleKo;
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
