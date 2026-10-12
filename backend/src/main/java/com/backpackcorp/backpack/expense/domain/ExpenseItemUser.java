package com.backpackcorp.backpack.expense.domain;

import java.math.BigDecimal;

import org.springframework.data.domain.Persistable;

import com.backpackcorp.backpack.trip.domain.TripMember;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.MapsId;
import jakarta.persistence.PostLoad;
import jakarta.persistence.PostPersist;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "expense_item_users")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ExpenseItemUser implements Persistable<ExpenseItemUserId> {

	@EmbeddedId
	private ExpenseItemUserId id;

	// ID를 직접 채우는 엔티티라 Spring Data가 새 엔티티인지 알 수 없다. 알려 주지 않으면 save()가
	// 저장할 때마다 SELECT를 먼저 날린다(merge). 저장되거나 조회된 뒤에는 true가 된다
	@Transient
	@Getter(AccessLevel.NONE)
	private boolean persisted;

	@MapsId("itemId")
	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "item_id", nullable = false)
	private ExpenseItem item;

	@MapsId("memberId")
	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "member_id", nullable = false)
	private TripMember member;

	// 모든 분담 방식에서 계산 결과를 저장한다 (원 단위 나머지는 결제자 몫)
	@Column(nullable = false, precision = 15, scale = 0)
	private BigDecimal shareKrw;

	// item과 member는 먼저 저장되어 ID가 있어야 한다
	@Builder
	private ExpenseItemUser(ExpenseItem item, TripMember member, BigDecimal shareKrw) {
		this.id = new ExpenseItemUserId(item.getId(), member.getId());
		this.item = item;
		this.member = member;
		this.shareKrw = shareKrw;
	}

	@Override
	public boolean isNew() {
		return !persisted;
	}

	@PostLoad
	@PostPersist
	private void markPersisted() {
		this.persisted = true;
	}
}
