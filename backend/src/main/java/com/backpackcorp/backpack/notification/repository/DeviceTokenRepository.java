package com.backpackcorp.backpack.notification.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.notification.domain.DeviceToken;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {
}
