package com.backpackcorp.backpack.trip.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.trip.domain.Trip;

public interface TripRepository extends JpaRepository<Trip, UUID> {
}
