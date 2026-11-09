package com.backpackcorp.backpack.expense;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

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

import com.backpackcorp.backpack.budget.domain.ExchangeRate;
import com.backpackcorp.backpack.budget.repository.ExchangeRateRepository;
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

// 지출 상세 · 수정 · 삭제 (BP-EX-005)와 정산 공유 (BP-ST-003)
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ExpenseEditAndShareApiTest {

	private static final LocalDate DAY = LocalDate.of(2026, 10, 3);

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
	@Autowired
	private ExchangeRateRepository exchangeRateRepository;

	private MockMvc mockMvc;
	private Trip trip;
	// 0 방장, 1 결제자, 2 다른 멤버
	private final List<TripMember> members = new ArrayList<>();
	private final List<String> tokens = new ArrayList<>();

	@BeforeEach
	void setUp() {
		mockMvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
		trip = tripRepository.save(Trip.builder().name("오사카").destination("일본 오사카").startDate(DAY)
			.endDate(DAY.plusDays(2)).currencyCode("JPY").timeZone("Asia/Tokyo").inviteCode("EDIT2345").build());
		String[] names = {"김방장", "이멤버", "박멤버"};
		for (int i = 0; i < names.length; i++) {
			User user = userRepository.save(User.builder().email("e" + i + "@b.c").passwordHash("{noop}x")
				.name(names[i]).build());
			members.add(tripMemberRepository.save(TripMember.builder().trip(trip).user(user)
				.role(i == 0 ? TripMemberRole.HOST : TripMemberRole.MEMBER).build()));
			tokens.add(tokenService.createAccessToken(user.getId(), Role.USER));
		}
		exchangeRateRepository.save(ExchangeRate.builder().currencyCode("JPY").rateDate(DAY)
			.rateToKrw(new BigDecimal("9.350000")).build());
	}

	@Test
	void 지출_상세는_항목과_사람별_분담을_준다() throws Exception {
		String id = createJpy(1, "3000", 0, 1, 2);

		perform(get(expense(id)), 2, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.amountKrw").value(28_050))
			.andExpect(jsonPath("$.items[0].members.length()").value(3))
			.andExpect(jsonPath("$.memberShares[?(@.isPayer == true)].memberId").value(id(1)))
			.andExpect(jsonPath("$.version").value(0));
		perform(get(expense(java.util.UUID.randomUUID().toString())), 2, null)
			.andExpect(status().isNotFound())
			.andExpect(jsonPath("$.code").value("EXPENSE_NOT_FOUND"));
	}

	@Test
	void 수정은_전체_교체이고_버전이_올라간다() throws Exception {
		String id = createJpy(1, "3000", 0, 1, 2);

		perform(put(expense(id)), 1, body(1, "4850", 0, "\"" + id(0) + "\",\"" + id(1) + "\""))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.amountKrw").value(45_348))
			.andExpect(jsonPath("$.items[0].members.length()").value(2))
			.andExpect(jsonPath("$.creator.memberId").value(id(1)))
			.andExpect(jsonPath("$.version").value(1));
		// 옛 버전으로 다시 보내면 충돌
		perform(put(expense(id)), 1, body(1, "1000", 0, "\"" + id(1) + "\""))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));

		perform(get("/api/trips/" + trip.getId() + "/settlement"), 0, null)
			.andExpect(jsonPath("$.totalKrw").value(45_348))
			.andExpect(jsonPath("$.members[2].shareKrw").value(0));
	}

	@Test
	void 결제자_작성자_방장만_고치거나_지울_수_있다() throws Exception {
		String id = createJpy(1, "3000", 0, 1, 2);

		perform(put(expense(id)), 2, body(1, "1000", 0, "\"" + id(2) + "\""))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("NOT_EXPENSE_EDITOR"));
		perform(delete(expense(id)), 2, null).andExpect(status().isForbidden());

		perform(delete(expense(id)), 0, null).andExpect(status().isNoContent());
		perform(get(expense(id)), 0, null).andExpect(status().isNotFound());
		perform(get("/api/trips/" + trip.getId() + "/settlement"), 0, null)
			.andExpect(jsonPath("$.totalKrw").value(0))
			.andExpect(jsonPath("$.transfers.length()").value(0));
	}

	@Test
	void 정산을_공유하면_그_시점의_송금_목록이_남는다() throws Exception {
		perform(post("/api/trips/" + trip.getId() + "/settlement-shares"), 0, null)
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("NOTHING_TO_SETTLE"));

		createJpy(1, "3000", 0, 1, 2);
		String shareBody = perform(post("/api/trips/" + trip.getId() + "/settlement-shares"), 0, null)
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.sharedBy.memberId").value(id(0)))
			.andExpect(jsonPath("$.transfers.length()").value(2))
			.andExpect(jsonPath("$.transfers[0].to.memberId").value(id(1)))
			.andExpect(jsonPath("$.transferTotalKrw").value(18_700))
			.andReturn().getResponse().getContentAsString();
		String shareId = JsonPath.read(shareBody, "$.id");

		// 이후 지출이 늘어도 공유한 목록은 그대로다
		createJpy(2, "1000", 0, 2);
		perform(get("/api/trips/" + trip.getId() + "/settlement-shares/" + shareId), 2, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.transferTotalKrw").value(18_700));
		perform(get("/api/trips/" + trip.getId() + "/settlement-shares"), 2, null)
			.andExpect(jsonPath("$.length()").value(1))
			.andExpect(jsonPath("$[0].transferCount").value(2));
	}

	private String createJpy(int payer, String amount, int... targets) throws Exception {
		List<String> ids = new ArrayList<>();
		for (int target : targets) {
			ids.add("\"" + id(target) + "\"");
		}
		String response = perform(post("/api/trips/" + trip.getId() + "/expenses"), payer,
			body(payer, amount, null, String.join(",", ids)))
			.andExpect(status().isCreated())
			.andReturn().getResponse().getContentAsString();
		return JsonPath.read(response, "$.id");
	}

	private String body(int payer, String amount, Integer version, String memberIds) {
		return """
			{"payerMemberId":"%s","title":"구로몬 시장","category":"FOOD","paidDate":"%s","rateMode":"API",
			 "amountLocal":%s,"splitMethod":"EQUAL","memberIds":[%s],"version":%s}
			""".formatted(id(payer), DAY, amount, memberIds, version);
	}

	private String expense(String id) {
		return "/api/trips/" + trip.getId() + "/expenses/" + id;
	}

	private String id(int member) {
		return members.get(member).getId().toString();
	}

	private ResultActions perform(MockHttpServletRequestBuilder request, int member, String body) throws Exception {
		request.header(HttpHeaders.AUTHORIZATION, "Bearer " + tokens.get(member));
		if (body != null) {
			request.contentType(MediaType.APPLICATION_JSON).content(body);
		}
		return mockMvc.perform(request);
	}
}
