package com.backpackcorp.backpack.notification.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.notification.domain.DeviceToken;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {

	Optional<DeviceToken> findByFcmToken(String fcmToken);

	@Query("select t.fcmToken from DeviceToken t where t.user.id in :userIds")
	List<String> findTokensByUserIds(@Param("userIds") Collection<UUID> userIds);

	@Modifying
	@Query("delete from DeviceToken t where t.fcmToken in :tokens")
	int deleteByTokens(@Param("tokens") Collection<String> tokens);

	@Modifying
	@Query("delete from DeviceToken t where t.fcmToken = :token and t.user.id = :userId")
	int deleteByTokenAndUser(@Param("token") String token, @Param("userId") UUID userId);
}
