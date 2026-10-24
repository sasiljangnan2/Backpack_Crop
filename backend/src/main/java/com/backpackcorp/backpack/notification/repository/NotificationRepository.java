package com.backpackcorp.backpack.notification.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.backpackcorp.backpack.notification.domain.Notification;

public interface NotificationRepository extends JpaRepository<Notification, UUID> {
}
