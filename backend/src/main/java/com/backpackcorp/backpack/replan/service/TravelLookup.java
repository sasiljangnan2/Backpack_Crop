package com.backpackcorp.backpack.replan.service;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.dto.TravelLeg;
import com.backpackcorp.backpack.place.service.TravelService;

// 재구성에 나오는 장소들의 이동 시간을 한 번에 받아 두고 찾는다 (공용 경로 서버에 요청을 하나로 모은다)
final class TravelLookup implements RulePlanner.Travel {

	private final TravelService travelService;
	private final Map<LatLng, Integer> index = new HashMap<>();
	private final Map<List<LatLng>, TravelLeg> extra = new HashMap<>();
	private final TravelLeg[][] matrix;

	TravelLookup(TravelService travelService, Collection<LatLng> points) {
		this.travelService = travelService;
		List<LatLng> distinct = new ArrayList<>(new LinkedHashSet<>(points.stream().filter(p -> p != null).toList()));
		for (int i = 0; i < distinct.size(); i++) {
			index.put(distinct.get(i), i);
		}
		this.matrix = travelService.matrix(distinct);
	}

	@Override
	public TravelLeg between(LatLng from, LatLng to) {
		Integer i = index.get(from);
		Integer j = index.get(to);
		if (i != null && j != null) {
			return matrix[i][j];
		}
		return extra.computeIfAbsent(List.of(from, to), key -> travelService.leg(from, to));
	}
}
