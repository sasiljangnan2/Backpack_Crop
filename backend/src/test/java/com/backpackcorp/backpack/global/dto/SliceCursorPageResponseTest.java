package com.backpackcorp.backpack.global.dto;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.SliceImpl;

class SliceCursorPageResponseTest {

	@Test
	void 다음_페이지가_있으면_마지막_항목의_값이_커서가_된다() {
		SliceImpl<Integer> slice = new SliceImpl<>(List.of(30, 20, 10), PageRequest.ofSize(3), true);

		SliceCursorPageResponse<Integer> response = SliceCursorPageResponse.from(slice, item -> item);

		assertThat(response.content()).containsExactly(30, 20, 10);
		assertThat(response.nextCursor()).isEqualTo("10");
		assertThat(response.hasNext()).isTrue();
	}

	@Test
	void 마지막_페이지나_빈_목록이면_커서가_없다() {
		SliceImpl<Integer> last = new SliceImpl<>(List.of(30, 20), PageRequest.ofSize(3), false);
		SliceImpl<Integer> empty = new SliceImpl<>(List.of());

		assertThat(SliceCursorPageResponse.from(last, item -> item).nextCursor()).isNull();
		assertThat(SliceCursorPageResponse.from(empty, item -> item))
			.isEqualTo(new SliceCursorPageResponse<>(List.of(), null, false));
	}
}
