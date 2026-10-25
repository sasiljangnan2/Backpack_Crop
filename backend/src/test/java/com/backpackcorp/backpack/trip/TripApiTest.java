package com.backpackcorp.backpack.trip;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import com.backpackcorp.backpack.global.security.TokenService;
import com.backpackcorp.backpack.trip.repository.TripRepository;
import com.backpackcorp.backpack.user.domain.Role;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;

// 시연 2단계: 여행 만들기 → 초대 코드 → 다른 계정이 참여. 시각은 2026-10-03 14:50 (도쿄)로 고정
@SpringBootTest(properties = "app.demo.now=2026-10-03T05:50:00Z")
@ActiveProfiles("test")
@Transactional
class TripApiTest {

	@Autowired
	private WebApplicationContext context;
	@Autowired
	private TokenService tokenService;
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private TripRepository tripRepository;

	private MockMvc mockMvc;
	private final List<String> tokens = new ArrayList<>();

	@BeforeEach
	void setUp() {
		mockMvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
		String[] names = {"김방장", "이멤버", "박멤버"};
		for (int i = 0; i < names.length; i++) {
			User user = userRepository.save(User.builder().email("u" + i + "@b.c").passwordHash("{noop}x")
				.name(names[i]).build());
			tokens.add(tokenService.createAccessToken(user.getId(), Role.USER));
		}
	}

	@Test
	void 여행을_만들면_초대_코드가_나오고_만든_사람이_방장이다() throws Exception {
		perform(post("/api/trips"), 0, createBody("2026-10-02", "2026-10-05"))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.inviteCode").value(org.hamcrest.Matchers.matchesPattern("[A-HJ-NP-Z2-9]{8}")))
			.andExpect(jsonPath("$.myRole").value("HOST"))
			.andExpect(jsonPath("$.currencyCode").value("JPY"))
			.andExpect(jsonPath("$.timeZone").value("Asia/Tokyo"))
			.andExpect(jsonPath("$.status").value("LIVE"))
			.andExpect(jsonPath("$.dayNo").value(2))
			.andExpect(jsonPath("$.nights").value(3))
			.andExpect(jsonPath("$.memberCount").value(1));
	}

	@Test
	void 여행_전에는_D_day를_준다() throws Exception {
		perform(post("/api/trips"), 0, createBody("2026-10-10", "2026-10-12"))
			.andExpect(jsonPath("$.status").value("UPCOMING"))
			.andExpect(jsonPath("$.dDay").value(7))
			.andExpect(jsonPath("$.dayNo").doesNotExist());
	}

	@Test
	void 잘못된_여행_정보는_400이다() throws Exception {
		perform(post("/api/trips"), 0, createBody("2026-10-05", "2026-10-02"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.endDate").exists());
		perform(post("/api/trips"), 0, """
			{"name":"","destination":"오사카","startDate":"2026-10-02","endDate":"2026-10-03","currencyCode":"XYZ"}
			""")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.name").exists());
		perform(post("/api/trips"), 0, """
			{"name":"a","destination":"b","startDate":"2026-10-02","endDate":"2026-10-03","currencyCode":"jpy",
			 "timeZone":"Mars/Olympus"}
			""")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.timeZone").exists());
	}

	@Test
	void 초대_코드로_참여하면_양쪽_여행_목록에_모두_보인다() throws Exception {
		String tripId = createTrip();
		String code = inviteCode(tripId);

		// 소문자 · 하이픈이 섞여도 받는다
		String messy = code.substring(0, 4).toLowerCase() + "-" + code.substring(4);
		perform(post("/api/trips/join"), 1, "{\"inviteCode\":\"" + messy + "\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.id").value(tripId))
			.andExpect(jsonPath("$.myRole").value("MEMBER"))
			.andExpect(jsonPath("$.memberCount").value(2));
		// 이미 멤버면 같은 여행을 그대로 돌려준다
		perform(post("/api/trips/join"), 1, "{\"inviteCode\":\"" + code + "\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.memberCount").value(2));

		perform(get("/api/trips"), 0, null)
			.andExpect(jsonPath("$[0].id").value(tripId))
			.andExpect(jsonPath("$[0].memberCount").value(2))
			.andExpect(jsonPath("$[0].myRole").value("HOST"));
		perform(get("/api/trips"), 1, null)
			.andExpect(jsonPath("$[0].id").value(tripId))
			.andExpect(jsonPath("$[0].myRole").value("MEMBER"));
	}

	@Test
	void 없는_초대_코드는_404_INVITE_CODE_NOT_FOUND다() throws Exception {
		perform(post("/api/trips/join"), 1, "{\"inviteCode\":\"ZZZZ9999\"}")
			.andExpect(status().isNotFound())
			.andExpect(jsonPath("$.code").value("INVITE_CODE_NOT_FOUND"));
	}

	@Test
	void 멤버가_아니면_여행_상세가_403이다() throws Exception {
		String tripId = createTrip();

		perform(get("/api/trips/" + tripId), 2, null)
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("NOT_TRIP_MEMBER"));
		perform(get("/api/trips/" + UUID.randomUUID()), 0, null)
			.andExpect(status().isForbidden());
		perform(get("/api/trips/" + tripId + "/schedules"), 2, null).andExpect(status().isForbidden());
		perform(get("/api/trips/" + tripId + "/expenses"), 2, null).andExpect(status().isForbidden());
	}

	@Test
	void 여행_수정과_삭제는_방장만_할_수_있다() throws Exception {
		String tripId = createTrip();
		join(tripId, 1);

		perform(patch("/api/trips/" + tripId), 1, "{\"name\":\"바뀐 이름\"}")
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("NOT_TRIP_HOST"));
		perform(patch("/api/trips/" + tripId), 0, "{\"name\":\"오사카 2박\",\"endDate\":\"2026-10-04\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.name").value("오사카 2박"))
			.andExpect(jsonPath("$.endDate").value("2026-10-04"));
		perform(delete("/api/trips/" + tripId), 1, null).andExpect(status().isForbidden());
	}

	@Test
	void 일정이_밀려나는_기간_변경과_지출이_있는_통화_변경은_막는다() throws Exception {
		String tripId = createTrip();
		perform(post("/api/trips/" + tripId + "/schedules"), 0, """
			{"day":"2026-10-05","startTime":"10:00","endTime":"11:00","title":"공항"}
			""").andExpect(status().isCreated());
		perform(patch("/api/trips/" + tripId), 0, "{\"endDate\":\"2026-10-04\"}")
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("TRIP_PERIOD_CONFLICT"))
			.andExpect(jsonPath("$.details.scheduleCount").value("1"));

		String me = JsonPath.read(perform(get("/api/trips/" + tripId), 0, null).andReturn().getResponse()
			.getContentAsString(), "$.myMemberId");
		perform(post("/api/trips/" + tripId + "/expenses"), 0, """
			{"payerMemberId":"%s","title":"택시","category":"TRANSPORT","paidDate":"2026-10-03","rateMode":"KRW",
			 "amountKrw":12000,"splitMethod":"EQUAL","memberIds":["%s"]}
			""".formatted(me, me)).andExpect(status().isCreated());
		perform(patch("/api/trips/" + tripId), 0, "{\"currencyCode\":\"USD\"}")
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("TRIP_CURRENCY_LOCKED"));
	}

	@Test
	void 방장이_나가면_다음_멤버가_방장이_되고_다시_참여할_수_있다() throws Exception {
		String tripId = createTrip();
		join(tripId, 1);
		join(tripId, 2);

		perform(delete("/api/trips/" + tripId + "/members/me"), 0, null).andExpect(status().isNoContent());

		perform(get("/api/trips/" + tripId), 0, null).andExpect(status().isForbidden());
		perform(get("/api/trips/" + tripId + "/members"), 1, null)
			.andExpect(jsonPath("$.length()").value(2))
			.andExpect(jsonPath("$[0].name").value("이멤버"))
			.andExpect(jsonPath("$[0].role").value("HOST"));

		// 다시 들어오면 일반 멤버다
		perform(post("/api/trips/join"), 0, "{\"inviteCode\":\"" + inviteCode(tripId, 1) + "\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.myRole").value("MEMBER"))
			.andExpect(jsonPath("$.memberCount").value(3));
	}

	@Test
	void 선불_환율을_설정하고_해제할_수_있다() throws Exception {
		String tripId = createTrip();
		perform(patch("/api/trips/" + tripId + "/members/me/prepaid-rate"), 0, "{\"prepaidRate\":9.12}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.prepaidRate").value(9.12));
		perform(patch("/api/trips/" + tripId + "/members/me/prepaid-rate"), 0, "{\"prepaidRate\":null}")
			.andExpect(jsonPath("$.prepaidRate").doesNotExist());
		perform(patch("/api/trips/" + tripId + "/members/me/prepaid-rate"), 0, "{\"prepaidRate\":-1}")
			.andExpect(status().isBadRequest());
	}

	@Test
	void 방장이_여행을_지우면_하위_데이터도_함께_지워진다() throws Exception {
		String tripId = createTrip();
		join(tripId, 1);
		perform(post("/api/trips/" + tripId + "/schedules"), 1, """
			{"day":"2026-10-03","startTime":"10:00","endTime":"11:00","title":"오사카성"}
			""").andExpect(status().isCreated());

		perform(delete("/api/trips/" + tripId), 0, null).andExpect(status().isNoContent());

		assertThat(tripRepository.findById(UUID.fromString(tripId))).isEmpty();
		perform(get("/api/trips"), 1, null).andExpect(jsonPath("$.length()").value(0));
	}

	private String createTrip() throws Exception {
		String body = perform(post("/api/trips"), 0, createBody("2026-10-02", "2026-10-05"))
			.andExpect(status().isCreated())
			.andReturn().getResponse().getContentAsString();
		return JsonPath.read(body, "$.id");
	}

	private void join(String tripId, int user) throws Exception {
		perform(post("/api/trips/join"), user, "{\"inviteCode\":\"" + inviteCode(tripId) + "\"}")
			.andExpect(status().isOk());
	}

	private String inviteCode(String tripId) throws Exception {
		return inviteCode(tripId, 0);
	}

	private String inviteCode(String tripId, int asUser) throws Exception {
		return JsonPath.read(perform(get("/api/trips/" + tripId), asUser, null).andReturn().getResponse()
			.getContentAsString(), "$.inviteCode");
	}

	private static String createBody(String start, String end) {
		return """
			{"name":"오사카 먹방","destination":"일본 오사카","startDate":"%s","endDate":"%s",
			 "currencyCode":"jpy","timeZone":"Asia/Tokyo"}
			""".formatted(start, end);
	}

	private ResultActions perform(MockHttpServletRequestBuilder request, int user, String body) throws Exception {
		request.header(HttpHeaders.AUTHORIZATION, "Bearer " + tokens.get(user));
		if (body != null) {
			request.contentType(MediaType.APPLICATION_JSON).content(body);
		}
		return mockMvc.perform(request);
	}
}
