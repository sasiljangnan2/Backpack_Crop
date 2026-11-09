package com.backpackcorp.backpack.schedule;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;

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
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.repository.TripRepository;
import com.backpackcorp.backpack.user.domain.Role;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;

// 시연 3~5단계. 지금은 2026-10-03 14:50 (도쿄)
@SpringBootTest(properties = "app.demo.now=2026-10-03T05:50:00Z")
@ActiveProfiles("test")
@Transactional
class ScheduleApiTest {

	private static final LocalDate TODAY = LocalDate.of(2026, 10, 3);

	@Autowired
	private WebApplicationContext context;
	@Autowired
	private TokenService tokenService;
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private TripRepository tripRepository;
	@Autowired
	private TripMemberRepository tripMemberRepository;

	private MockMvc mockMvc;
	private Trip trip;
	private String token;

	@BeforeEach
	void setUp() {
		mockMvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
		User user = userRepository.save(User.builder().email("host@b.c").passwordHash("{noop}x").name("김방장").build());
		trip = tripRepository.save(Trip.builder().name("오사카").destination("일본 오사카")
			.startDate(TODAY.minusDays(1)).endDate(TODAY.plusDays(2)).currencyCode("JPY").timeZone("Asia/Tokyo")
			.inviteCode("SCHE2345").build());
		tripMemberRepository.save(TripMember.builder().trip(trip).user(user).role(TripMemberRole.HOST).build());
		token = tokenService.createAccessToken(user.getId(), Role.USER);
	}

	@Test
	void 일정을_추가하면_날짜별로_시간순_조회된다() throws Exception {
		create("12:00", "13:30", "구로몬 시장", false).andExpect(status().isCreated())
			.andExpect(jsonPath("$.startTime").value("12:00"))
			.andExpect(jsonPath("$.status").value("PLANNED"))
			.andExpect(jsonPath("$.version").value(0))
			.andExpect(jsonPath("$.createdBy.name").value("김방장"));
		create("09:00", "11:00", "오사카성", false).andExpect(status().isCreated());
		perform(post(schedules()), """
			{"day":"%s","startTime":"10:00","endTime":"11:00","title":"공항"}
			""".formatted(TODAY.plusDays(1))).andExpect(status().isCreated());

		perform(get(schedules()).param("day", TODAY.toString()), null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.length()").value(2))
			.andExpect(jsonPath("$[0].title").value("오사카성"))
			.andExpect(jsonPath("$[1].title").value("구로몬 시장"));
		perform(get(schedules()), null).andExpect(jsonPath("$.length()").value(3));
	}

	@Test
	void 시간이_겹치면_409와_함께_겹친_일정을_알려_준다() throws Exception {
		create("12:00", "13:30", "구로몬 시장", false).andExpect(status().isCreated());

		create("13:00", "14:00", "카페", false)
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("SCHEDULE_OVERLAP"))
			.andExpect(jsonPath("$.details.title").value("구로몬 시장"))
			.andExpect(jsonPath("$.details.startTime").value("12:00"))
			.andExpect(jsonPath("$.details.endTime").value("13:30"))
			.andExpect(jsonPath("$.details.overlapCount").value("1"));
		// 끝나는 시각에 시작하는 것은 겹침이 아니다
		create("13:30", "14:00", "카페", false).andExpect(status().isCreated());
	}

	@Test
	void 시간_범위와_날짜가_잘못되면_400이다() throws Exception {
		create("14:00", "13:00", "거꾸로", false)
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("INVALID_TIME_RANGE"));
		perform(post(schedules()), """
			{"day":"%s","startTime":"10:00","endTime":"11:00","title":"여행 밖"}
			""".formatted(TODAY.plusDays(10)))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("SCHEDULE_OUT_OF_TRIP"));
		perform(post(schedules()), "{\"day\":\"%s\",\"title\":\"\"}".formatted(TODAY))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.startTime").exists())
			.andExpect(jsonPath("$.details.title").exists());
	}

	@Test
	void 고정된_일정은_고정을_풀어야_시간을_바꾸거나_지울_수_있다() throws Exception {
		String id = idOf(create("18:00", "20:00", "저녁 예약", true));

		perform(patch(schedule(id)), "{\"version\":0,\"startTime\":\"18:30\"}")
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("SCHEDULE_LOCKED"));
		perform(patch(schedule(id)), "{\"version\":0,\"isLocked\":false,\"startTime\":\"18:30\"}")
			.andExpect(status().isConflict());
		perform(delete(schedule(id)), null).andExpect(status().isConflict());

		perform(patch(schedule(id)), "{\"version\":0,\"isLocked\":false}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.isLocked").value(false))
			.andExpect(jsonPath("$.version").value(1));
		perform(patch(schedule(id)), "{\"version\":1,\"startTime\":\"18:30\",\"memo\":\"창가 자리\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.startTime").value("18:30"))
			.andExpect(jsonPath("$.memo").value("창가 자리"))
			.andExpect(jsonPath("$.version").value(2));
		perform(delete(schedule(id)), null).andExpect(status().isNoContent());
	}

	@Test
	void 버전이_다르면_409_VERSION_CONFLICT다() throws Exception {
		String id = idOf(create("12:00", "13:30", "구로몬 시장", false));
		perform(patch(schedule(id)), "{\"version\":0,\"title\":\"구로몬 시장 (아침)\"}").andExpect(status().isOk());

		// 다른 사람이 먼저 고친 뒤 옛 버전으로 보낸 요청
		perform(patch(schedule(id)), "{\"version\":0,\"title\":\"덮어쓰기\"}")
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));
		perform(patch(schedule(id)), "{\"title\":\"버전 없음\"}")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.version").exists());
	}

	@Test
	void 수정할_때도_다른_일정과의_겹침을_검사한다() throws Exception {
		create("09:00", "11:00", "오사카성", false);
		String id = idOf(create("12:00", "13:30", "구로몬 시장", false));

		perform(patch(schedule(id)), "{\"version\":0,\"startTime\":\"10:30\"}")
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.details.title").value("오사카성"));
		// 자기 자신과는 겹침으로 보지 않는다
		perform(patch(schedule(id)), "{\"version\":0,\"endTime\":\"14:00\"}").andExpect(status().isOk());
	}

	@Test
	void 오늘_요약은_지금_일정_다음_고정_일정까지_남은_시간과_누적_지연을_준다() throws Exception {
		String castle = idOf(create("09:00", "11:00", "오사카성", false));
		String market = idOf(create("12:00", "13:30", "구로몬 시장", false));
		create("14:00", "15:30", "도톤보리", false);
		create("16:00", "17:00", "숙소 휴식", false);
		create("18:00", "20:00", "저녁 예약", true);

		// 오사카성은 45분 늦게 끝났다
		perform(put(schedule(castle) + "/activity"), "{\"actualStartTime\":\"09:10\",\"actualEndTime\":\"11:45\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.status").value("DONE"))
			.andExpect(jsonPath("$.activity.delayMin").value(45));

		perform(get("/api/trips/" + trip.getId() + "/today"), null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.date").value(TODAY.toString()))
			.andExpect(jsonPath("$.localTime").value("14:50"))
			.andExpect(jsonPath("$.tripStatus").value("LIVE"))
			.andExpect(jsonPath("$.dayNo").value(2))
			.andExpect(jsonPath("$.current.title").value("도톤보리"))
			.andExpect(jsonPath("$.next.title").value("숙소 휴식"))
			.andExpect(jsonPath("$.nextFixed.schedule.title").value("저녁 예약"))
			.andExpect(jsonPath("$.nextFixed.minutesUntil").value(190))
			.andExpect(jsonPath("$.delayMin").value(45))
			.andExpect(jsonPath("$.doneCount").value(1))
			.andExpect(jsonPath("$.total").value(5))
			.andExpect(jsonPath("$.remaining").value(4));

		// 구로몬 시장 완료 기록 (POST도 받는다). 제시간에 끝나 지연은 그대로 45분
		perform(post(schedule(market) + "/activity"), "{\"actualStartTime\":\"12:05\",\"actualEndTime\":\"13:20\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.activity.delayMin").value(0));
		perform(get("/api/trips/" + trip.getId() + "/today"), null)
			.andExpect(jsonPath("$.doneCount").value(2))
			.andExpect(jsonPath("$.remaining").value(3))
			.andExpect(jsonPath("$.delayMin").value(45));

		// 다시 기록하면 덮어쓰고 지연을 다시 계산한다
		perform(put(schedule(market) + "/activity"), "{\"actualStartTime\":\"12:05\",\"actualEndTime\":\"13:50\"}")
			.andExpect(jsonPath("$.activity.delayMin").value(20));
		perform(get("/api/trips/" + trip.getId() + "/today"), null).andExpect(jsonPath("$.delayMin").value(65));

		// 기록을 취소하면 다시 예정 상태
		perform(delete(schedule(market) + "/activity"), null).andExpect(status().isNoContent());
		perform(get("/api/trips/" + trip.getId() + "/today"), null)
			.andExpect(jsonPath("$.doneCount").value(1))
			.andExpect(jsonPath("$.delayMin").value(45));
	}

	@Test
	void 활동_기록의_종료가_시작보다_이르면_400이다() throws Exception {
		String id = idOf(create("09:00", "11:00", "오사카성", false));

		perform(put(schedule(id) + "/activity"), "{\"actualStartTime\":\"11:00\",\"actualEndTime\":\"10:00\"}")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("INVALID_TIME_RANGE"));
	}

	@Test
	void 다른_여행의_일정_ID로는_찾을_수_없다() throws Exception {
		String id = idOf(create("09:00", "11:00", "오사카성", false));
		Trip other = tripRepository.save(Trip.builder().name("다른 여행").destination("서울")
			.startDate(TODAY).endDate(TODAY).currencyCode("KRW").inviteCode("OTHR2345").build());
		tripMemberRepository.save(TripMember.builder().trip(other)
			.user(userRepository.findByEmail("host@b.c").orElseThrow()).role(TripMemberRole.HOST).build());

		perform(get("/api/trips/" + other.getId() + "/schedules/" + id), null)
			.andExpect(status().isNotFound())
			.andExpect(jsonPath("$.code").value("SCHEDULE_NOT_FOUND"));
	}

	private ResultActions create(String start, String end, String title, boolean locked) throws Exception {
		return perform(post(schedules()), """
			{"day":"%s","startTime":"%s","endTime":"%s","title":"%s","placeText":"오사카","isLocked":%s}
			""".formatted(TODAY, start, end, title, locked));
	}

	private static String idOf(ResultActions result) throws Exception {
		return JsonPath.read(result.andReturn().getResponse().getContentAsString(), "$.id");
	}

	private String schedules() {
		return "/api/trips/" + trip.getId() + "/schedules";
	}

	private String schedule(String id) {
		return schedules() + "/" + id;
	}

	private ResultActions perform(MockHttpServletRequestBuilder request, String body) throws Exception {
		request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
		if (body != null) {
			request.contentType(MediaType.APPLICATION_JSON).content(body);
		}
		return mockMvc.perform(request);
	}
}
