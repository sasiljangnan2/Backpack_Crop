package com.backpackcorp.backpack.global.dto;

import java.util.List;
import java.util.function.Function;

import org.springframework.data.domain.Slice;

// 커서 방식 목록 응답 (앱의 무한 스크롤용).
// 앱은 nextCursor를 다음 요청의 cursor 파라미터로 그대로 돌려보내고, hasNext가 false면 더 부르지 않는다.
// 페이지 번호 방식과 달리 전체 개수를 세지 않고, 스크롤하는 사이 새 글이 들어와도 항목이 겹치거나 빠지지 않는다
public record SliceCursorPageResponse<T>(
	List<T> content,
	String nextCursor,
	boolean hasNext
) {

	// cursorOf: 항목에서 커서로 쓸 값을 꺼낸다. 정렬 기준과 같은 값이어야 한다.
	// ID가 UUID v7(생성 시각순)이라 최신순 목록은 ID 하나로 커서를 삼을 수 있다.
	// 사용 예:
	//   첫 페이지(커서 없음)
	//     Slice<Notification> findByUserIdOrderByIdDesc(UUID userId, Pageable pageable);
	//   그다음 페이지(커서 = 앞 페이지의 nextCursor)
	//     Slice<Notification> findByUserIdAndIdLessThanOrderByIdDesc(UUID userId, UUID cursor, Pageable pageable);
	//   응답
	//     SliceCursorPageResponse.from(slice.map(NotificationResponse::from), NotificationResponse::id)
	public static <T> SliceCursorPageResponse<T> from(Slice<T> slice, Function<T, ?> cursorOf) {
		List<T> content = slice.getContent();
		String nextCursor = slice.hasNext() ? String.valueOf(cursorOf.apply(content.getLast())) : null;
		return new SliceCursorPageResponse<>(content, nextCursor, slice.hasNext());
	}
}
