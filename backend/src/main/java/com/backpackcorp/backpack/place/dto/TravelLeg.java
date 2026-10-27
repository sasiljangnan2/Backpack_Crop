package com.backpackcorp.backpack.place.dto;

import java.io.Serializable;

// 두 장소 사이 이동. 걸어서 20분 이내면 도보, 아니면 대중교통(구글 경로가 있을 때), 없으면 차(어림값)로 본다.
// estimated: 경로 서버에 닿지 못해 직선거리로 어림한 도보 값 (NFR-02: 경로 API가 실패해도 일정은 보여 준다)
// transitMin: 구글 대중교통 경로 시간. 구글 키가 없거나 경로가 없으면 null
public record TravelLeg(
	TravelMode mode,
	int minutes,
	int distanceM,
	int walkMin,
	int driveMin,
	Integer transitMin,
	boolean estimated
) implements Serializable {

	public static final int WALK_LIMIT_MIN = 20;

	public static TravelLeg of(int distanceM, int walkMin, int driveMin, boolean estimated) {
		return of(distanceM, walkMin, driveMin, null, estimated);
	}

	public static TravelLeg of(int distanceM, int walkMin, int driveMin, Integer transitMin, boolean estimated) {
		// 대중교통이 없는 곳은 구글이 걷기만 하는 경로를 대중교통으로 돌려준다. 걷기보다 빠를 때만 대중교통으로 본다
		if (transitMin != null && transitMin >= walkMin) {
			transitMin = null;
		}
		TravelMode mode = walkMin <= WALK_LIMIT_MIN ? TravelMode.WALK
			: transitMin != null ? TravelMode.TRANSIT : TravelMode.DRIVE;
		int minutes = switch (mode) {
			case WALK -> walkMin;
			case TRANSIT -> transitMin;
			case DRIVE -> driveMin;
		};
		return new TravelLeg(mode, minutes, distanceM, walkMin, driveMin, transitMin, estimated);
	}

	public enum TravelMode {
		WALK,
		TRANSIT,
		DRIVE
	}
}
