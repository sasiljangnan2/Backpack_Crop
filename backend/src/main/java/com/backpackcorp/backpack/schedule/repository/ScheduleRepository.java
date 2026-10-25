package com.backpackcorp.backpack.schedule.repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.schedule.domain.Schedule;

public interface ScheduleRepository extends JpaRepository<Schedule, UUID> {

	// day가 null이면 전체. 날짜 → 시작 시각순
	@Query("""
		select s from Schedule s
		join fetch s.createdBy m
		left join fetch m.user
		where s.trip.id = :tripId and (:day is null or s.day = :day)
		order by s.day, s.startTime, s.id
		""")
	List<Schedule> findByTrip(@Param("tripId") UUID tripId, @Param("day") LocalDate day);

	// 같은 날 일정 (겹침 검사용)
	List<Schedule> findByTripIdAndDayOrderByStartTime(UUID tripId, LocalDate day);

	@Query("""
		select s from Schedule s
		join fetch s.createdBy m
		left join fetch m.user
		where s.id = :id and s.trip.id = :tripId
		""")
	Optional<Schedule> findInTrip(@Param("id") UUID id, @Param("tripId") UUID tripId);

	// 여행 기간을 바꿀 때 밖으로 밀려나는 일정 수
	@Query("select count(s) from Schedule s where s.trip.id = :tripId and (s.day < :start or s.day > :end)")
	long countOutside(@Param("tripId") UUID tripId, @Param("start") LocalDate start, @Param("end") LocalDate end);
}
