package com.backpackcorp.backpack.replan;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.replan.domain.PlanKey;
import com.backpackcorp.backpack.replan.service.AiPlanner;
import com.backpackcorp.backpack.replan.service.Stop;
import com.backpackcorp.backpack.support.ApiTestSupport;
import com.jayway.jsonpath.JsonPath;

// AI가 같은 곳을 같은 순서로 들르는 안을 두 번 내도 앱에는 서로 다른 3안이 간다.
// 지금은 2026-10-03 14:50 (오사카). 고정 일정 21:00 전까지 세 곳을 다시 짠다
@SpringBootTest(properties = "app.demo.now=2026-10-03T05:50:00Z")
@ActiveProfiles("test")
@Transactional
@ExtendWith(OutputCaptureExtension.class)
class ReplanAiMergeApiTest extends ApiTestSupport {

	private static final LocalDate TODAY = LocalDate.of(2026, 10, 3);

	@MockitoBean
	private AiPlanner aiPlanner;

	private String park;
	private String shopping;
	private String food;

	@BeforeEach
	void setUp() throws Exception {
		setUpTrip(TODAY.minusDays(1), TODAY.plusDays(2), "JPY", "김방장");
		park = create("15:00", "15:30", "나카노시마 공원", 34.6927, 135.5060, "PARK", false);
		shopping = create("16:00", "17:00", "신사이바시 쇼핑", 34.6745, 135.5013, "SHOPPING", false);
		food = create("17:30", "18:10", "도톤보리 먹거리", 34.6687, 135.5013, "FOOD", false);
		create("21:00", "22:00", "우메다 스카이빌딩", 34.7053, 135.4896, "SIGHT", true);
		when(aiPlanner.available()).thenReturn(true);
	}

	@Test
	void AI가_1안과_같은_2안을_내면_2안은_규칙_기반_이동_최소_안으로_바꾼다(CapturedOutput output) throws Exception {
		// 2안(이동 최소)이 1안과 같은 순서
		answer(new String[] {"신사이바시 쇼핑", "나카노시마 공원", "도톤보리 먹거리"},
			new String[] {"신사이바시 쇼핑", "나카노시마 공원", "도톤보리 먹거리"},
			new String[] {"도톤보리 먹거리", "나카노시마 공원", "신사이바시 쇼핑"});

		String body = recommend()
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.source").value("AI"))
			.andExpect(jsonPath("$.plans[0].reason").value("AI 조건 안"))
			.andExpect(jsonPath("$.plans[2].reason").value("AI 여유 안"))
			.andReturn().getResponse().getContentAsString();

		// 2안: 지금 있는 구로몬 시장에서 가까운 순서 (규칙 기반)
		List<String> second = JsonPath.read(body, "$.plans[1].items[*].title");
		assertThat(second).containsExactly("도톤보리 먹거리", "신사이바시 쇼핑", "나카노시마 공원");
		assertThat((String)JsonPath.read(body, "$.plans[1].reason")).isNotEqualTo("AI 이동 안");
		List<List<String>> routes = List.of(
			JsonPath.read(body, "$.plans[0].items[*].title"), second, JsonPath.read(body, "$.plans[2].items[*].title"));
		assertThat(routes).doesNotHaveDuplicates();
		assertThat(output).contains("AI '이동 최소' 안이 앞의 안과 같은 순서라 규칙 기반 안으로 바꿈");
	}

	@Test
	void 바꿀_규칙_기반_안도_같으면_그_안은_빼고_보낸다(CapturedOutput output) throws Exception {
		// 1안이 규칙 기반 이동 최소 안(가까운 순서)과 같은 순서라 2안은 바꿔도 겹친다
		answer(new String[] {"도톤보리 먹거리", "신사이바시 쇼핑", "나카노시마 공원"},
			new String[] {"도톤보리 먹거리", "신사이바시 쇼핑", "나카노시마 공원"},
			new String[] {"신사이바시 쇼핑", "나카노시마 공원", "도톤보리 먹거리"});

		String body = recommend()
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.source").value("AI"))
			.andExpect(jsonPath("$.plans.length()").value(2))
			.andExpect(jsonPath("$.plans[0].key").value("CONDITION"))
			.andExpect(jsonPath("$.plans[1].key").value("SLACK"))
			.andReturn().getResponse().getContentAsString();
		assertThat(output).contains("'이동 최소' 안이 앞의 안과 같은 순서라 빼고 보냄");

		// 남은 안은 그대로 적용할 수 있다
		perform(post(tripUrl() + "/replan/apply"), 0,
			"{\"requestId\":\"%s\",\"planKey\":\"SLACK\"}".formatted((String)JsonPath.read(body, "$.requestId")))
			.andExpect(status().isOk());
	}

	@Test
	void AI_안을_하나도_못_쓰고_겹치는_안만_빠지면_기본_추천으로_알린다() throws Exception {
		// AI가 고른 곳이 없다 → 모두 규칙 기반 안. 그중 여유 안이 조건 안(원래 순서)과 같아 빠진다
		answer(new String[0], new String[0], new String[0]);

		recommend()
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.source").value("RULE"))
			.andExpect(jsonPath("$.notice").value("AI 추천이 시간에 맞지 않아 기본 추천을 보여 드려요."))
			.andExpect(jsonPath("$.plans.length()").value(2));
	}

	@Test
	void AI_안이_서로_다르면_그대로_보낸다(CapturedOutput output) throws Exception {
		answer(new String[] {"신사이바시 쇼핑", "나카노시마 공원", "도톤보리 먹거리"},
			new String[] {"도톤보리 먹거리", "신사이바시 쇼핑", "나카노시마 공원"},
			new String[] {"나카노시마 공원", "신사이바시 쇼핑", "도톤보리 먹거리"});

		recommend()
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.plans[0].reason").value("AI 조건 안"))
			.andExpect(jsonPath("$.plans[1].reason").value("AI 이동 안"))
			.andExpect(jsonPath("$.plans[2].reason").value("AI 여유 안"));
		assertThat(output).doesNotContain("규칙 기반 안으로 바꿈").doesNotContain("빼고 보냄");
	}

	// AI가 각 안에서 들를 곳을 이 제목 순서로 고른 것처럼 답한다
	private void answer(String[] condition, String[] minTravel, String[] slack) {
		when(aiPlanner.suggest(any())).thenAnswer(call -> {
			AiPlanner.Context context = call.getArgument(0);
			return List.of(
				new AiPlanner.Draft(PlanKey.CONDITION, stops(context, condition), "AI 조건 안"),
				new AiPlanner.Draft(PlanKey.MIN_TRAVEL, stops(context, minTravel), "AI 이동 안"),
				new AiPlanner.Draft(PlanKey.SLACK, stops(context, slack), "AI 여유 안"));
		});
	}

	private static List<Stop> stops(AiPlanner.Context context, String[] titles) {
		return List.of(titles).stream()
			.map(title -> context.targets().stream().filter(s -> s.title().equals(title)).findFirst().orElseThrow())
			.toList();
	}

	private ResultActions recommend() throws Exception {
		return perform(post(tripUrl() + "/replan"), 0, """
			{"currentPlace":{"name":"구로몬 시장","lat":34.6655,"lng":135.5066,"fromGps":false},
			 "scheduleIds":["%s","%s","%s"]}
			""".formatted(park, shopping, food));
	}

	private String create(String start, String end, String title, double lat, double lng, String category,
		boolean locked) throws Exception {
		ResultActions result = perform(post(tripUrl() + "/schedules"), 0, """
			{"day":"%s","startTime":"%s","endTime":"%s","title":"%s","placeText":"%s",
			 "placeLat":%s,"placeLng":%s,"placeCategory":"%s","isLocked":%s}
			""".formatted(TODAY, start, end, title, title, lat, lng, category, locked))
			.andExpect(status().isCreated());
		return read(result, "$.id");
	}
}
