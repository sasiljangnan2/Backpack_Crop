package com.backpackcorp.backpack.expense.repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.expense.domain.Expense;
import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.dto.CategoryAmountDto;
import com.backpackcorp.backpack.expense.dto.ExpenseTotalsDto;
import com.backpackcorp.backpack.expense.dto.MemberAmountDto;

public interface ExpenseRepository extends JpaRepository<Expense, UUID> {

	boolean existsByTripId(UUID tripId);

	@Query("""
		select e from Expense e
		join fetch e.payer p
		left join fetch p.user
		join fetch e.creator c
		left join fetch c.user
		where e.id = :id and e.trip.id = :tripId
		""")
	Optional<Expense> findDetail(@Param("id") UUID id, @Param("tripId") UUID tripId);

	// 결제일 내림차순, 같은 날은 최근 등록순(UUID v7). 커서는 앞 페이지 마지막 항목의 (결제일, ID)다.
	// date·category가 null이면 거르지 않는다. 첫 페이지는 cursorDate를 null로 부른다
	@Query("""
		select e from Expense e
		join fetch e.payer p
		left join fetch p.user
		where e.trip.id = :tripId
		  and (:date is null or e.paidDate = :date)
		  and (:category is null or e.category = :category)
		  and (:cursorDate is null or e.paidDate < :cursorDate or (e.paidDate = :cursorDate and e.id < :cursorId))
		order by e.paidDate desc, e.id desc
		""")
	Slice<Expense> findPage(@Param("tripId") UUID tripId, @Param("date") LocalDate date,
		@Param("category") ExpenseCategory category, @Param("cursorDate") LocalDate cursorDate,
		@Param("cursorId") UUID cursorId, Pageable pageable);

	@Query("""
		select new com.backpackcorp.backpack.expense.dto.ExpenseTotalsDto(count(e), sum(e.amountKrw))
		from Expense e
		where e.trip.id = :tripId
		  and (:date is null or e.paidDate = :date)
		  and (:category is null or e.category = :category)
		""")
	ExpenseTotalsDto sumByTrip(@Param("tripId") UUID tripId, @Param("date") LocalDate date,
		@Param("category") ExpenseCategory category);

	// 예산 현황: 분류별 지출
	@Query("""
		select new com.backpackcorp.backpack.expense.dto.CategoryAmountDto(e.category, sum(e.amountKrw))
		from Expense e
		where e.trip.id = :tripId
		group by e.category
		""")
	List<CategoryAmountDto> sumByCategory(@Param("tripId") UUID tripId);

	// 정산: 멤버별로 낸 돈
	@Query("""
		select new com.backpackcorp.backpack.expense.dto.MemberAmountDto(e.payer.id, sum(e.amountKrw))
		from Expense e
		where e.trip.id = :tripId
		group by e.payer.id
		""")
	List<MemberAmountDto> sumPaidByMember(@Param("tripId") UUID tripId);

	// 계산 근거: 내가 결제했거나 분담한 지출 (최근 결제일순)
	@Query("""
		select e from Expense e
		join fetch e.payer p
		left join fetch p.user
		where e.trip.id = :tripId
		  and (e.payer.id = :memberId or exists (
		    select 1 from ExpenseItemUser u where u.item.expense = e and u.member.id = :memberId))
		order by e.paidDate desc, e.id desc
		""")
	List<Expense> findInvolving(@Param("tripId") UUID tripId, @Param("memberId") UUID memberId);
}
