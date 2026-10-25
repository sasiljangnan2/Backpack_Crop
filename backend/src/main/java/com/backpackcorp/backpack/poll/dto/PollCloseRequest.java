package com.backpackcorp.backpack.poll.dto;

import java.util.UUID;

// selectedOptionId가 있으면 그 후보로 슬롯에 일정을 만들고, 없으면 일정 없이 마감만 한다
public record PollCloseRequest(
	UUID selectedOptionId
) {
}
