package com.backpackcorp.backpack.task.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.backpackcorp.backpack.task.domain.Task;

public interface TaskRepository extends JpaRepository<Task, UUID> {

	// 함께 할 업무 전체 + 내가 만든 개인 업무. 안 한 일 먼저, 그다음 만든 순서
	@Query("""
		select t from Task t
		join fetch t.creator c
		left join fetch c.user
		left join fetch t.assignee a
		left join fetch a.user
		where t.trip.id = :tripId
		  and (t.scope = com.backpackcorp.backpack.task.domain.TaskScope.TEAM or t.creator.id = :memberId)
		order by t.done, t.id
		""")
	List<Task> findVisible(@Param("tripId") UUID tripId, @Param("memberId") UUID memberId);

	@Query("""
		select t from Task t
		join fetch t.creator c
		left join fetch c.user
		left join fetch t.assignee a
		left join fetch a.user
		where t.id = :id and t.trip.id = :tripId
		""")
	Optional<Task> findInTrip(@Param("id") UUID id, @Param("tripId") UUID tripId);
}
