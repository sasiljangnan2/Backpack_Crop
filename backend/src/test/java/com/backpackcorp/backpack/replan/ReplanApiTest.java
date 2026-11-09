package com.backpackcorp.backpack.replan;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.support.ApiTestSupport;
import com.jayway.jsonpath.JsonPath;

// BP-AI-002 · 003 · SC-004. 지금은 2026-10-03 14:50 (오사카). 테스트에는 AI 키 · 지도 서버가 없다
// (규칙 기반 추천 · 직선거리 어림값)
@SpringBootTest(properties = "app.demo.now=2026-10-03T05:50:00Z")
@ActiveProfiles("test")
@Transactional
class ReplanApiTest extends ApiTestSupport {

	private static final LocalDate TODAY = LocalDate.of(2026, 10, 3);

	private String kuromon;
	private String shinsaibashi;
	private String nakanoshima;
	private String umeda;

	@BeforeEach
	void setUp() throws Exception {
		setUpTrip(TODAY.minusDays(1), TODAY.plusDays(2), "JPY", "김방장", "이멤버");
		kuromon = create("13:30", "14:30", "구로몬 시장", 34.6655, 135.5066, "FOOD", false);
		shinsaibashi = create("15:00", "16:00", "신사이바시 쇼핑", 34.6745, 135.5013, "SHOPPING", false);
		nakanoshima = create("16:30", "17:15", "나카노시마 산책", 34.6927, 135.5060, "SIGHT", false);
		umeda = create("17:30", "19:00", "우메다 스카이빌딩", 34.7053, 135.4896, "SIGHT", true);
		perform(put(tripUrl() + "/schedules/" + kuromon + "/activity"), 0,
			"{\"actualStartTime\":\"14:15\",\"actualEndTime\":\"14:50\"}").andExpect(status().isOk());
	}

	@Test
	void 일정에_장소_좌표를_넣으면_그날_동선을_어림해_준다() throws Exception {
		perform(get(tripUrl() + "/schedules").param("day", TODAY.toString()), 0, null)
			.andExpect(jsonPath("$[0].placeLat").value(34.6655))
			.andExpect(jsonPath("$[0].placeCategory").value("FOOD"))
			.andExpect(jsonPath("$[0].replanned").value(false));

		perform(get(tripUrl() + "/schedules/route").param("day", TODAY.toString()), 0, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.legs.length()").value(3))
			.andExpect(jsonPath("$.legs[0].fromScheduleId").value(kuromon))
			.andExpect(jsonPath("$.legs[0].toScheduleId").value(shinsaibashi))
			// 지도 서버가 없으면 직선거리로 어림한다
			.andExpect(jsonPath("$.legs[0].travel.estimated").value(true))
			.andExpect(jsonPath("$.legs[0].travel.mode").value("WALK"))
			.andExpect(jsonPath("$.placedCount").value(4))
			.andExpect(jsonPath("$.missingPlaceCount").value(0));
	}

	@Test
	void 장소_이름만_바꾸면_좌표는_지워진다() throws Exception {
		perform(patch(tripUrl() + "/schedules/" + nakanoshima), 0, "{\"version\":0,\"placeText\":\"어딘가\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.placeText").value("어딘가"))
			.andExpect(jsonPath("$.placeLat").doesNotExist())
			.andExpect(jsonPath("$.placeCategory").doesNotExist());
	}

	@Test
	void 남은_일정을_3안으로_추천하고_고른_안을_적용한다() throws Exception {
		ResultActions result = recommend(List.of(shinsaibashi, nakanoshima), "\"REST\",\"INDOOR\"")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.source").value("RULE"))
			.andExpect(jsonPath("$.notice").exists())
			.andExpect(jsonPath("$.context.currentPlace").value("구로몬 시장"))
			.andExpect(jsonPath("$.context.now").value("14:50"))
			.andExpect(jsonPath("$.context.windowEnd").value("17:30"))
			.andExpect(jsonPath("$.context.doneCount").value(1))
			.andExpect(jsonPath("$.context.delayMin").value(20))
			.andExpect(jsonPath("$.context.anchor.title").value("우메다 스카이빌딩"))
			.andExpect(jsonPath("$.context.anchor.isLocked").value(true))
			.andExpect(jsonPath("$.plans.length()").value(3))
			.andExpect(jsonPath("$.plans[0].key").value("CONDITION"))
			.andExpect(jsonPath("$.plans[1].key").value("MIN_TRAVEL"))
			.andExpect(jsonPath("$.plans[2].key").value("SLACK"));
		String body = result.andReturn().getResponse().getContentAsString();
		// 모든 안이 고정 일정 전에 끝나고, 휴식 조건 안에는 쉬어 가는 일정이 들어간다
		List<Integer> slacks = JsonPath.read(body, "$.plans[*].slackMin");
		assertThat(slacks).allMatch(slack -> slack >= 0);
		// 조건 일치 안: 실내(쇼핑)를 남기고 쉬어 가는 일정을 넣는다. 시간이 모자란 산책은 빠진다
		List<String> conditionTitles = JsonPath.read(body, "$.plans[0].items[*].title");
		assertThat(conditionTitles).containsExactly("신사이바시 쇼핑", "잠깐 쉬어 가기");
		List<String> dropped = JsonPath.read(body, "$.plans[0].dropped[*].title");
		assertThat(dropped).containsExactly("나카노시마 산책");
		String requestId = JsonPath.read(body, "$.requestId");

		perform(post(tripUrl() + "/replan/apply"), 0,
			"{\"requestId\":\"%s\",\"planKey\":\"CONDITION\"}".formatted(requestId))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$[?(@.title == '잠깐 쉬어 가기')].replanned").value(true))
			.andExpect(jsonPath("$[?(@.title == '우메다 스카이빌딩')].startTime").value("17:30"))
			.andExpect(jsonPath("$[?(@.title == '우메다 스카이빌딩')].replanned").value(false))
			.andExpect(jsonPath("$[?(@.title == '나카노시마 산책')]").isEmpty());

		// 한 번 적용한 추천은 다시 쓸 수 없다
		perform(post(tripUrl() + "/replan/apply"), 0,
			"{\"requestId\":\"%s\",\"planKey\":\"SLACK\"}".formatted(requestId))
			.andExpect(status().isGone())
			.andExpect(jsonPath("$.code").value("REPLAN_EXPIRED"));
	}

	@Test
	void 추천_뒤_다른_사람이_일정을_바꾸면_적용하지_않는다() throws Exception {
		String requestId = JsonPath.read(recommend(List.of(shinsaibashi, nakanoshima), "")
			.andReturn().getResponse().getContentAsString(), "$.requestId");
		perform(patch(tripUrl() + "/schedules/" + nakanoshima), 1, "{\"version\":0,\"memo\":\"늦게 가요\"}")
			.andExpect(status().isOk());

		perform(post(tripUrl() + "/replan/apply"), 0,
			"{\"requestId\":\"%s\",\"planKey\":\"MIN_TRAVEL\"}".formatted(requestId))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("REPLAN_STALE"));
	}

	@Test
	void 고정_일정이나_끝난_일정은_다시_짤_수_없다() throws Exception {
		recommend(List.of(umeda), "")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("REPLAN_INVALID_TARGET"));
		recommend(List.of(kuromon), "")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("REPLAN_INVALID_TARGET"));
	}

	@Test
	void 직접_고른_현재_장소를_쓴다() throws Exception {
		perform(post(tripUrl() + "/replan"), 0, """
			{"currentPlace":{"name":"구로몬 시장 입구","lat":34.6660,"lng":135.5070,"fromGps":false},
			 "scheduleIds":["%s"]}
			""".formatted(shinsaibashi))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.context.currentPlace").value("구로몬 시장 입구"))
			.andExpect(jsonPath("$.context.currentPlaceFromGps").value(false))
			// 그대로 둘 다음 일정(산책 16:30)까지 갈 수 있게 맞춘다
			.andExpect(jsonPath("$.context.anchor.title").value("나카노시마 산책"))
			.andExpect(jsonPath("$.plans[1].items[0].title").value("신사이바시 쇼핑"));
	}

	private ResultActions recommend(List<String> ids, String conditions) throws Exception {
		String list = String.join("\",\"", ids);
		return perform(post(tripUrl() + "/replan"), 0,
			"{\"conditions\":[%s],\"scheduleIds\":[\"%s\"]}".formatted(conditions, list));
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
