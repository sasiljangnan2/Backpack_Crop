package com.backpackcorp.backpack.place.service;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.backpackcorp.backpack.place.domain.LatLng;
import com.backpackcorp.backpack.place.dto.TravelLeg;

import lombok.RequiredArgsConstructor;

// 장소 사이 이동 시간.
//   도보: 구글 경로(키가 있을 때) → OpenStreetMap 경로(OSRM) → 직선거리 어림값(estimated = true)
//   대중교통: 걸어서 20분이 넘는 구간이 있으면 구글 대중교통 경로 (키가 있을 때만)
//   차: 늘 어림값이다. 도보 경로 거리를 시내 평균 속도로 나누고 타고 내리는 시간을 더한다
@Service
@RequiredArgsConstructor
public class TravelService {

	// 직선거리에 길이 돌아가는 만큼을 더한다
	static final double DETOUR = 1.3;
	// 걷는 속도 4.5km/h, 시내 차 평균 25km/h (m/분)
	static final double WALK_M_PER_MIN = 75;
	static final double DRIVE_M_PER_MIN = 416;
	// 차 시간에는 택시를 잡거나 역까지 걷는 시간을 더한다
	static final int DRIVE_OVERHEAD_MIN = 5;
	// 한 번에 묻는 장소 수 (공용 서버에 큰 요청을 보내지 않는다)
	static final int MAX_POINTS = 25;

	private final GoogleMapsClient google;
	private final OsmClient osm;

	public TravelLeg leg(LatLng from, LatLng to) {
		return matrix(List.of(from, to))[0][1];
	}

	// points[i] → points[j] 이동. 대각선(같은 장소)은 0분
	public TravelLeg[][] matrix(List<LatLng> points) {
		int n = points.size();
		TravelLeg[][] legs = new TravelLeg[n][n];
		if (n == 0) {
			return legs;
		}
		OsmClient.Matrix foot = null;
		if (n >= 2 && n <= MAX_POINTS) {
			foot = google.routeMatrix("WALK", points);
			if (foot == null) {
				foot = osm.walkTable(points.stream().map(LatLng::osrm).collect(Collectors.joining(";")));
			}
		}
		fill(legs, points, foot, null);
		boolean longWalk = false;
		for (TravelLeg[] row : legs) {
			for (TravelLeg leg : row) {
				longWalk |= leg.walkMin() > TravelLeg.WALK_LIMIT_MIN;
			}
		}
		if (longWalk && n >= 2) {
			OsmClient.Matrix transit = google.routeMatrix("TRANSIT", points);
			if (transit != null) {
				fill(legs, points, foot, transit);
			}
		}
		return legs;
	}

	private static void fill(TravelLeg[][] legs, List<LatLng> points, OsmClient.Matrix foot,
		OsmClient.Matrix transit) {
		for (int i = 0; i < points.size(); i++) {
			for (int j = 0; j < points.size(); j++) {
				legs[i][j] = i == j ? TravelLeg.of(0, 0, 0, false)
					: leg(points.get(i), points.get(j), foot, transit, i, j);
			}
		}
	}

	private static TravelLeg leg(LatLng from, LatLng to, OsmClient.Matrix foot, OsmClient.Matrix transit, int i,
		int j) {
		double straight = from.distanceTo(to) * DETOUR;
		Double walkSec = cell(foot == null ? null : foot.durationsSec(), i, j);
		Double walkDist = cell(foot == null ? null : foot.distancesM(), i, j);
		boolean estimated = walkSec == null;
		double distance = walkDist != null ? walkDist : straight;
		int walkMin = walkSec != null ? minutes(walkSec) : minutes(straight / WALK_M_PER_MIN * 60);
		int driveMin = minutes(distance / DRIVE_M_PER_MIN * 60) + DRIVE_OVERHEAD_MIN;
		Double transitSec = cell(transit == null ? null : transit.durationsSec(), i, j);
		Integer transitMin = transitSec == null ? null : minutes(transitSec);
		return TravelLeg.of((int)Math.round(distance), walkMin, driveMin, transitMin, estimated);
	}

	private static Double cell(Double[][] table, int i, int j) {
		if (table == null || i >= table.length || table[i] == null || j >= table[i].length) {
			return null;
		}
		return table[i][j];
	}

	// 같은 자리면 0분, 아니면 올려서 1분 이상
	private static int minutes(double seconds) {
		return seconds < 1 ? 0 : (int)Math.max(1, Math.ceil(seconds / 60));
	}
}
