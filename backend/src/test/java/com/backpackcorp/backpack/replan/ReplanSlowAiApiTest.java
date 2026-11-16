package com.backpackcorp.backpack.replan;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.startsWith;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.replan.service.AiPlanner;
import com.backpackcorp.backpack.support.ApiTestSupport;

// AI가 늦거나 실패해도 정해진 시간 안에 규칙 기반 추천으로 답한다 (앱이 "서버 응답이 늦어요"로 끝나지 않게).
// 쇼핑이 14:00에 시작했어야 했는데 14:50인 지금까지 못 갔다
@SpringBootTest(properties = {"app.demo.now=2026-10-03T05:50:00Z", "ai.replan-timeout=1s"})
@ActiveProfiles("test")
@Transactional
class ReplanSlowAiApiTest extends ApiTestSupport {

	private static final LocalDate TODAY = LocalDate.of(2026, 10, 3);

	@MockitoBean
	private AiPlanner aiPlanner;

	private String shopping;

	@BeforeEach
	void setUp() throws Exception {
		setUpTrip(TODAY.minusDays(1), TODAY.plusDays(2), "JPY", "김방장");
		shopping = read(perform(post(tripUrl() + "/schedules"), 0, """
			{"day":"%s","startTime":"14:00","endTime":"15:00","title":"신사이바시 쇼핑"}
			""".formatted(TODAY)).andExpect(status().isCreated()), "$.id");
		when(aiPlanner.available()).thenReturn(true);
	}

	@Test
	void AI가_늦으면_기다리지_않고_기본_추천을_준다() throws Exception {
		when(aiPlanner.suggest(any())).thenAnswer(call -> {
			Thread.sleep(5_000);
			return List.of();
		});
		long started = System.currentTimeMillis();

		recommend()
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.source").value("RULE"))
			.andExpect(jsonPath("$.notice", startsWith("AI 응답이 늦어 기본 추천을 보여 드려요.")))
			// 일정이 하나라 세 기준의 안이 모두 같다: 하나로 합쳐 보여 준다
			.andExpect(jsonPath("$.plans.length()").value(1))
			.andExpect(jsonPath("$.plans[0].label").value("조건 일치 우선 · 이동 최소 · 시간 여유 우선"))
			.andExpect(jsonPath("$.plans[0].startTime").value("14:50"));

		assertThat(System.currentTimeMillis() - started).isLessThan(4_000);
	}

	@Test
	void AI가_실패하면_기본_추천을_준다() throws Exception {
		when(aiPlanner.suggest(any())).thenThrow(new IllegalStateException("503"));

		recommend()
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.source").value("RULE"))
			.andExpect(jsonPath("$.notice", startsWith("AI 응답을 받지 못해 기본 추천을 보여 드려요.")));
	}

	@Test
	void 추천안이_모두_지금_일정과_같으면_안을_보여_주지_않는다() throws Exception {
		when(aiPlanner.suggest(any())).thenThrow(new IllegalStateException("503"));
		String onTime = read(perform(post(tripUrl() + "/schedules"), 0, """
			{"day":"%s","startTime":"15:00","endTime":"16:00","title":"카페"}
			""".formatted(TODAY)).andExpect(status().isCreated()), "$.id");

		perform(post(tripUrl() + "/replan"), 0, "{\"scheduleIds\":[\"%s\"]}".formatted(onTime))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.plans.length()").value(0))
			.andExpect(jsonPath("$.notice").value("바꿀 만한 추천안이 없어요. 지금 일정이 이미 고른 조건에 잘 맞아요. (AI 응답은 받지 못했어요)"));
	}

	private ResultActions recommend() throws Exception {
		return perform(post(tripUrl() + "/replan"), 0, "{\"scheduleIds\":[\"%s\"]}".formatted(shopping));
	}
}
