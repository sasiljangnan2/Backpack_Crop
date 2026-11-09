package com.backpackcorp.backpack.schedule.service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.place.dto.TravelLeg;
import com.backpackcorp.backpack.place.service.TravelService;
import com.backpackcorp.backpack.schedule.domain.Schedule;
import com.backpackcorp.backpack.schedule.dto.DayRouteResponse;
import com.backpackcorp.backpack.schedule.repository.ScheduleRepository;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.RequiredArgsConstructor;

// 그날 일정 사이 이동 (카드 사이 "도보 8분 · 650m", 지도의 총 이동 거리 · 시간)
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ScheduleRouteService {

	private final TripMemberGuard tripMemberGuard;
	private final ScheduleRepository scheduleRepository;
	private final TravelService travelService;

	public DayRouteResponse dayRoute(UUID tripId, UUID userId, LocalDate day) {
		tripMemberGuard.requireMember(tripId, userId);
		List<Schedule> schedules = scheduleRepository.findByTripIdAndDayOrderByStartTime(tripId, day);
		List<Schedule> placed = schedules.stream().filter(s -> s.place() != null).toList();
		List<DayRouteResponse.Leg> legs = new ArrayList<>();
		int distance = 0;
		int minutes = 0;
		if (placed.size() >= 2) {
			TravelLeg[][] matrix = travelService.matrix(placed.stream().map(Schedule::place).toList());
			for (int i = 0; i + 1 < placed.size(); i++) {
				TravelLeg leg = matrix[i][i + 1];
				legs.add(new DayRouteResponse.Leg(placed.get(i).getId(), placed.get(i + 1).getId(), leg));
				distance += leg.distanceM();
				minutes += leg.minutes();
			}
		}
		return new DayRouteResponse(day, legs, distance, minutes, placed.size(), schedules.size() - placed.size());
	}
}
