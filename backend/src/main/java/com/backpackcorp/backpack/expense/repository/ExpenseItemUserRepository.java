package com.backpackcorp.backpack.expense.repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.expense.domain.ExpenseItemUser;
import com.backpackcorp.backpack.expense.domain.ExpenseItemUserId;
import com.backpackcorp.backpack.expense.dto.ExpenseAmountDto;
import com.backpackcorp.backpack.expense.dto.MemberAmountDto;

public interface ExpenseItemUserRepository extends JpaRepository<ExpenseItemUser, ExpenseItemUserId> {

	// 항목 순서, 같은 항목 안에서는 멤버가 참여한 순서
	@Query("""
		select u from ExpenseItemUser u
		join fetch u.member m
		left join fetch m.user
		where u.item.id in :itemIds
		order by m.joinedAt, m.id
		""")
	List<ExpenseItemUser> findWithMemberByItemIds(@Param("itemIds") Collection<UUID> itemIds);

	@Modifying(flushAutomatically = true, clearAutomatically = true)
	@Query("""
		delete from ExpenseItemUser u
		where u.item.id in (select i.id from ExpenseItem i where i.expense.id = :expenseId)
		""")
	void deleteByExpenseId(@Param("expenseId") UUID expenseId);

	// 정산: 멤버별로 부담할 돈
	@Query("""
		select new com.backpackcorp.backpack.expense.dto.MemberAmountDto(u.member.id, sum(u.shareKrw))
		from ExpenseItemUser u
		where u.item.expense.trip.id = :tripId
		group by u.member.id
		""")
	List<MemberAmountDto> sumShareByMember(@Param("tripId") UUID tripId);

	// 정산 전 송금: 지출마다 각자 결제자에게 바로 보낸다면 생기는 (보내는 사람, 받는 사람) 쌍
	@Query("""
		select distinct u.member.id, u.item.expense.payer.id
		from ExpenseItemUser u
		where u.item.expense.trip.id = :tripId
		  and u.shareKrw > 0
		  and u.member.id <> u.item.expense.payer.id
		""")
	List<Object[]> findDebtPairs(@Param("tripId") UUID tripId);

	// 지출별 내 부담액
	@Query("""
		select new com.backpackcorp.backpack.expense.dto.ExpenseAmountDto(u.item.expense.id, sum(u.shareKrw))
		from ExpenseItemUser u
		where u.member.id = :memberId and u.item.expense.id in :expenseIds
		group by u.item.expense.id
		""")
	List<ExpenseAmountDto> sumShareByExpense(@Param("memberId") UUID memberId,
		@Param("expenseIds") Collection<UUID> expenseIds);
}
