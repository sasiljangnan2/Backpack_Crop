package com.backpackcorp.backpack.budget.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.budget.domain.ExchangeRate;

public interface ExchangeRateRepository extends JpaRepository<ExchangeRate, UUID> {
}
