package com.backpackcorp.backpack.poll.dto;

import java.util.UUID;

import jakarta.validation.constraints.NotNull;

public record PollVoteRequest(
	@NotNull(message = "후보를 선택해 주세요.")
	UUID optionId
) {
}
