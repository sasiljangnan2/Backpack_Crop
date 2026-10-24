package com.backpackcorp.backpack.settlement.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.settlement.domain.SettlementTransfer;

public interface SettlementTransferRepository extends JpaRepository<SettlementTransfer, UUID> {
}
