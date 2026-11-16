package com.backpackcorp.backpack.fund.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.expense.dto.MemberAmountDto;
import com.backpackcorp.backpack.fund.domain.FundContribution;

public interface FundContributionRepository extends JpaRepository<FundContribution, UUID> {

	// 최근 모은 순
	@Query("""
		select c from FundContribution c
		join fetch c.member m
		left join fetch m.user
		join fetch c.creator w
		left join fetch w.user
		where c.trip.id = :tripId
		order by c.contributedOn desc, c.id desc
		""")
	List<FundContribution> findAllWithMembers(@Param("tripId") UUID tripId);

	@Query("""
		select c from FundContribution c
		join fetch c.member m
		join fetch c.creator w
		where c.id = :id and c.trip.id = :tripId
		""")
	Optional<FundContribution> findInTrip(@Param("id") UUID id, @Param("tripId") UUID tripId);

	// 멤버별로 모은 돈
	@Query("""
		select new com.backpackcorp.backpack.expense.dto.MemberAmountDto(c.member.id, sum(c.amountKrw))
		from FundContribution c
		where c.trip.id = :tripId
		group by c.member.id
		""")
	List<MemberAmountDto> sumByMember(@Param("tripId") UUID tripId);
}
