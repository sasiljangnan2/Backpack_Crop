package com.backpackcorp.backpack.notification.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.notification.domain.Notification;

public interface NotificationRepository extends JpaRepository<Notification, UUID> {

	// 알림함 첫 페이지. ID가 UUID v7이라 ID 내림차순 = 최신순
	Slice<Notification> findByUserIdOrderByIdDesc(UUID userId, Pageable pageable);

	// 그다음 페이지 (커서 = 앞 페이지 마지막 알림 ID)
	Slice<Notification> findByUserIdAndIdLessThanOrderByIdDesc(UUID userId, UUID cursor, Pageable pageable);

	Optional<Notification> findByIdAndUserId(UUID id, UUID userId);

	long countByUserIdAndReadFalse(UUID userId);

	@Modifying(flushAutomatically = true, clearAutomatically = true)
	@Query("update Notification n set n.read = true where n.user.id = :userId and n.read = false")
	int markAllRead(@Param("userId") UUID userId);
}
