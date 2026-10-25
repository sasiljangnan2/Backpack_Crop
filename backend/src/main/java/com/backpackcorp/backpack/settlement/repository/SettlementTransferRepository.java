package com.backpackcorp.backpack.settlement.repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.settlement.domain.SettlementTransfer;

public interface SettlementTransferRepository extends JpaRepository<SettlementTransfer, UUID> {

	// 저장한 순서 = 금액 큰 순
	@Query("""
		select t from SettlementTransfer t
		join fetch t.fromMember f
		left join fetch f.user
		join fetch t.toMember r
		left join fetch r.user
		where t.share.id in :shareIds
		order by t.id
		""")
	List<SettlementTransfer> findWithMembersByShareIds(@Param("shareIds") Collection<UUID> shareIds);
}
