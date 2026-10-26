package com.backpackcorp.backpack.trip.dto;

import jakarta.validation.constraints.NotBlank;

// 초대 코드로 참여 요청. 소문자로 와도 TripService가 대문자로 바꿔 찾는다
public record TripJoinRequest(@NotBlank String inviteCode) {
}
