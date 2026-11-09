package com.backpackcorp.backpack.expense;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.hamcrest.Matchers;
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

// 시연 6~7단계: 엔화 지출 → 원화 환산 → 5명 균등 분담과 끝전 → 정산 송금 경로 → 계산 근거
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ExpenseSettlementApiTest {

	private static final LocalDate DAY1 = LocalDate.of(2026, 10, 3);
	private static final LocalDate DAY2 = DAY1.plusDays(1);

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
	// 0번이 방장. 시안의 5명 여행
	private final List<TripMember> members = new ArrayList<>();
	private final List<String> tokens = new ArrayList<>();

	@BeforeEach
	void setUp() {
		mockMvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
		trip = tripRepository.save(Trip.builder().name("오사카 먹방").destination("일본 오사카")
			.startDate(DAY1).endDate(DAY1.plusDays(3)).currencyCode("JPY").inviteCode("TEST2345").build());
		String[] names = {"김방장", "이멤버", "박멤버", "최멤버", "정멤버"};
		for (int i = 0; i < names.length; i++) {
			User user = userRepository.save(User.builder().email("m" + i + "@b.c").passwordHash("{noop}x")
				.name(names[i]).build());
			members.add(tripMemberRepository.save(TripMember.builder().trip(trip).user(user)
				.role(i == 0 ? TripMemberRole.HOST : TripMemberRole.MEMBER)
				.prepaidRate(i == 1 ? new BigDecimal("8.900000") : null).build()));
			tokens.add(tokenService.createAccessToken(user.getId(), Role.USER));
		}
		// 둘째 날 이후 환율은 없다 → 셋째 날 지출은 둘째 날 값으로 대체된다
		exchangeRateRepository.save(rate("JPY", DAY1, "9.050000"));
		exchangeRateRepository.save(rate("JPY", DAY2, "9.350000"));
		exchangeRateRepository.save(rate("USD", DAY2, "1382.500000"));
	}

	@Test
	void 엔화_지출을_원화로_바꾸고_5명이_나누면_끝전은_결제자가_부담한다() throws Exception {
		// 4,850엔 × 9.35 = 45,347.5 → 45,348원. 1인 9,069원, 끝전 3원은 결제자(2번)
		perform(post(expensesUrl()), 0, equalBody(2, "API", "4850", DAY2, 0, 1, 2, 3, 4))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.id").exists())
			.andExpect(jsonPath("$.currencyCode").value("JPY"))
			.andExpect(jsonPath("$.appliedRate").value(9.35))
			.andExpect(jsonPath("$.rateDate").value(DAY2.toString()))
			.andExpect(jsonPath("$.amountKrw").value(45_348))
			.andExpect(jsonPath("$.creator.memberId").value(id(0)))
			.andExpect(jsonPath("$.payer.memberId").value(id(2)))
			.andExpect(jsonPath("$.items[0].remainderKrw").value(3))
			.andExpect(jsonPath("$.items[0].remainderMember.memberId").value(id(2)))
			.andExpect(jsonPath("$.memberShares[?(@.memberId == '" + id(2) + "')].shareKrw").value(9_072))
			.andExpect(jsonPath("$.memberShares[?(@.memberId == '" + id(0) + "')].shareKrw").value(9_069))
			.andExpect(jsonPath("$.memberShares[?(@.memberId == '" + id(2) + "')].isPayer").value(true))
			.andExpect(jsonPath("$.version").value(0));
	}

	@Test
	void 결제자가_분담_대상이_아니면_첫_번째_대상이_끝전을_부담한다() throws Exception {
		perform(post(expensesUrl()), 0, krwEqualBody(0, 10_000, 1, 2, 3))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.items[0].remainderMember.memberId").value(id(1)))
			.andExpect(jsonPath("$.items[0].members[0].shareKrw").value(3_334))
			.andExpect(jsonPath("$.items[0].members[1].shareKrw").value(3_333));
	}

	@Test
	void 미리보기는_계산만_하고_저장하지_않는다() throws Exception {
		perform(post(expensesUrl() + "/preview"), 1, equalBody(1, "API", "4850", DAY2, 0, 1, 2, 3, 4))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.id").doesNotExist())
			.andExpect(jsonPath("$.amountKrw").value(45_348))
			.andExpect(jsonPath("$.items[0].remainderMember.memberId").value(id(1)));

		perform(get(expensesUrl()), 1, null)
			.andExpect(jsonPath("$.summary.count").value(0))
			.andExpect(jsonPath("$.content").isEmpty());
	}

	@Test
	void 환율이_없는_날은_가장_가까운_이전_날짜_값을_쓴다() throws Exception {
		perform(post(expensesUrl()), 0, equalBody(0, "API", "1000", DAY2.plusDays(1), 0, 1))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.appliedRate").value(9.35))
			.andExpect(jsonPath("$.rateDate").value(DAY2.toString()))
			.andExpect(jsonPath("$.amountKrw").value(9_350));

		perform(get("/api/exchange-rates").param("currency", "jpy").param("date", DAY2.plusDays(5).toString()), 0,
			null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.currencyCode").value("JPY"))
			.andExpect(jsonPath("$.rateDate").value(DAY2.toString()))
			.andExpect(jsonPath("$.unit").value(100))
			.andExpect(jsonPath("$.unitRateToKrw").value(935.0))
			.andExpect(jsonPath("$.isFallback").value(true));
	}

	@Test
	void 환율이_아예_없으면_404다() throws Exception {
		perform(get("/api/exchange-rates").param("currencyCode", "JPY").param("date", "2020-01-01"), 0, null)
			.andExpect(status().isNotFound())
			.andExpect(jsonPath("$.code").value("EXCHANGE_RATE_NOT_FOUND"));
		perform(get("/api/exchange-rates").param("currencyCode", "JP"), 0, null)
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.currencyCode").exists());
	}

	@Test
	void 선불_환율과_직접_입력_환율을_쓸_수_있다() throws Exception {
		// 1번 멤버의 선불 환율 8.9 → 1,000엔 = 8,900원
		perform(post(expensesUrl()), 1, equalBody(1, "PREPAID", "1000", DAY2, 0, 1))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.amountKrw").value(8_900))
			.andExpect(jsonPath("$.rateDate").doesNotExist());
		// 선불 환율이 없는 사람
		perform(post(expensesUrl()), 0, equalBody(0, "PREPAID", "1000", DAY2, 0, 1))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("PREPAID_RATE_NOT_SET"));
		perform(post(expensesUrl()), 0, """
			{"payerMemberId":"%s","title":"편의점","category":"FOOD","paidDate":"%s","rateMode":"MANUAL",
			 "amountLocal":1000,"manualRate":9.1,"splitMethod":"EQUAL","memberIds":["%s"]}
			""".formatted(id(0), DAY2, id(0)))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.amountKrw").value(9_100));
	}

	@Test
	void 항목별_분담은_항목마다_나누고_합계가_총액과_같다() throws Exception {
		// 라멘 A 1,200엔(0번) + 라멘 B·맥주 3,650엔(1, 2번). 환율 9.35
		String body = """
			{"payerMemberId":"%s","title":"이치란","category":"FOOD","paidDate":"%s","rateMode":"API",
			 "amountLocal":4850,"splitMethod":"ITEM","items":[
			   {"name":"라멘 A","amountLocal":1200,"members":[{"memberId":"%s"}]},
			   {"name":"라멘 B + 맥주","amountLocal":3650,"members":[{"memberId":"%s"},{"memberId":"%s"}]}]}
			""".formatted(id(0), DAY2, id(0), id(1), id(2));
		perform(post(expensesUrl()), 0, body)
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.amountKrw").value(45_348))
			.andExpect(jsonPath("$.items[0].amountKrw").value(11_220))
			.andExpect(jsonPath("$.items[1].amountKrw").value(34_128))
			.andExpect(jsonPath("$.items[1].members[0].shareKrw").value(17_064))
			.andExpect(jsonPath("$.items[1].members[1].shareKrw").value(17_064));
	}

	@Test
	void 개별_분담은_합계가_총액과_같아야_한다() throws Exception {
		String body = """
			{"payerMemberId":"%s","title":"택시","category":"TRANSPORT","paidDate":"%s","rateMode":"KRW",
			 "amountKrw":12000,"splitMethod":"CUSTOM","items":[{"members":[
			   {"memberId":"%s","shareKrw":%d},{"memberId":"%s","shareKrw":5000}]}]}
			""";
		perform(post(expensesUrl()), 0, body.formatted(id(0), DAY1, id(0), 6000, id(1)))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("INVALID_EXPENSE"))
			.andExpect(jsonPath("$.details['items[0].members']").exists());
		perform(post(expensesUrl()), 0, body.formatted(id(0), DAY1, id(0), 7000, id(1)))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.items[0].remainderKrw").value(0));
	}

	@Test
	void 필수값이_없거나_규칙에_맞지_않으면_400이다() throws Exception {
		perform(post(expensesUrl()), 0, """
			{"title":"","category":"FOOD","paidDate":"%s","rateMode":"KRW","amountKrw":-1,"splitMethod":"EQUAL"}
			""".formatted(DAY1))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
			.andExpect(jsonPath("$.details.payerMemberId").exists())
			.andExpect(jsonPath("$.details.title").exists())
			.andExpect(jsonPath("$.details.amountKrw").exists());
		// 분담 대상 없음
		perform(post(expensesUrl()), 0, krwEqualBody(0, 10_000))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.items").exists());
		// 원화 입력인데 외화 금액도 보냄
		perform(post(expensesUrl()), 0, """
			{"payerMemberId":"%s","title":"x","category":"FOOD","paidDate":"%s","rateMode":"KRW","amountKrw":100,
			 "amountLocal":10,"splitMethod":"EQUAL","memberIds":["%s"]}
			""".formatted(id(0), DAY1, id(0)))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("INVALID_EXPENSE"));
		// 다른 여행의 멤버를 분담자로 지정
		perform(post(expensesUrl()), 0, """
			{"payerMemberId":"%s","title":"x","category":"FOOD","paidDate":"%s","rateMode":"KRW","amountKrw":100,
			 "splitMethod":"EQUAL","memberIds":["%s"]}
			""".formatted(id(0), DAY1, UUID.randomUUID()))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details['items[0].members[0].memberId']").exists());
	}

	@Test
	void 멤버가_아니면_403이고_토큰이_없으면_401이다() throws Exception {
		String stranger = tokenService.createAccessToken(UUID.randomUUID(), Role.USER);
		mockMvc.perform(get(expensesUrl()).header(HttpHeaders.AUTHORIZATION, "Bearer " + stranger))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("NOT_TRIP_MEMBER"));
		mockMvc.perform(get("/api/trips/" + trip.getId() + "/settlement")
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + stranger))
			.andExpect(status().isForbidden());
		mockMvc.perform(get(expensesUrl()))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
	}

	@Test
	void 목록은_공동_지출_합계와_내_부담액을_함께_주고_커서로_넘긴다() throws Exception {
		perform(post(expensesUrl()), 0, krwEqualBody(0, 30_000, 0, 1, 2)).andExpect(status().isCreated());
		perform(post(expensesUrl()), 1, krwEqualBody(1, 12_000, 1, 3)).andExpect(status().isCreated());
		perform(post(expensesUrl()), 2, equalBody(2, "API", "4850", DAY2, 0, 1, 2, 3, 4))
			.andExpect(status().isCreated());

		String firstPage = perform(get(expensesUrl()).param("size", "2"), 1, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.content.length()").value(2))
			// 결제일 최신순: 둘째 날 엔화 지출이 먼저
			.andExpect(jsonPath("$.content[0].amountKrw").value(45_348))
			.andExpect(jsonPath("$.content[0].myShareKrw").value(9_069))
			.andExpect(jsonPath("$.content[1].isPaidByMe").value(true))
			.andExpect(jsonPath("$.hasNext").value(true))
			.andExpect(jsonPath("$.summary.count").value(3))
			.andExpect(jsonPath("$.summary.totalKrw").value(87_348))
			.andExpect(jsonPath("$.summary.currencyCode").value("JPY"))
			// 분류 비율 막대: 금액이 큰 분류부터 (식비 45,348 · 교통 30,000 + 12,000)
			.andExpect(jsonPath("$.summary.byCategory[0].category").value("FOOD"))
			.andExpect(jsonPath("$.summary.byCategory[0].amountKrw").value(45_348))
			.andExpect(jsonPath("$.summary.byCategory[1].amountKrw").value(42_000))
			.andExpect(jsonPath("$.content[0].creator.memberId").value(id(2)))
			.andReturn().getResponse().getContentAsString();
		String cursor = com.jayway.jsonpath.JsonPath.read(firstPage, "$.nextCursor");

		perform(get(expensesUrl()).param("size", "2").param("cursor", cursor), 1, null)
			.andExpect(jsonPath("$.content.length()").value(1))
			.andExpect(jsonPath("$.content[0].amountKrw").value(30_000))
			.andExpect(jsonPath("$.content[0].myShareKrw").value(10_000))
			.andExpect(jsonPath("$.hasNext").value(false))
			.andExpect(jsonPath("$.nextCursor").doesNotExist());

		perform(get(expensesUrl()).param("cursor", "garbage"), 1, null)
			.andExpect(status().isBadRequest());
	}

	@Test
	void 정산은_사람별_잔액과_송금_경로를_주고_계산_근거와_맞는다() throws Exception {
		// 0번 30,000원 (0,1,2) / 1번 12,000원 (1,3) / 2번 4,850엔=45,348원 (5명)
		perform(post(expensesUrl()), 0, krwEqualBody(0, 30_000, 0, 1, 2)).andExpect(status().isCreated());
		perform(post(expensesUrl()), 1, krwEqualBody(1, 12_000, 1, 3)).andExpect(status().isCreated());
		perform(post(expensesUrl()), 2, equalBody(2, "API", "4850", DAY2, 0, 1, 2, 3, 4))
			.andExpect(status().isCreated());

		// 잔액: 0번 +10,931 / 1번 −13,069 / 2번 +26,276 / 3번 −15,069 / 4번 −9,069
		perform(get("/api/trips/" + trip.getId() + "/settlement"), 0, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.totalKrw").value(87_348))
			.andExpect(jsonPath("$.expenseCount").value(3))
			.andExpect(jsonPath("$.members.length()").value(5))
			.andExpect(jsonPath("$.members[0].balanceKrw").value(10_931))
			.andExpect(jsonPath("$.members[0].isMe").value(true))
			.andExpect(jsonPath("$.members[1].balanceKrw").value(-13_069))
			.andExpect(jsonPath("$.members[1].status").value("SEND"))
			.andExpect(jsonPath("$.members[2].balanceKrw").value(26_276))
			.andExpect(jsonPath("$.members[3].balanceKrw").value(-15_069))
			.andExpect(jsonPath("$.members[4].balanceKrw").value(-9_069))
			.andExpect(jsonPath("$.transferTotalKrw").value(37_207))
			// 바로 갚으면: 0번 지출 1·2→0, 1번 지출 3→1, 2번 지출 0·1·3·4→2 = 7건
			.andExpect(jsonPath("$.directTransferCount").value(7))
			.andExpect(jsonPath("$.transfers.length()").value(Matchers.lessThanOrEqualTo(4)));

		perform(get("/api/trips/" + trip.getId() + "/settlement/me"), 1, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.me.memberId").value(id(1)))
			.andExpect(jsonPath("$.paidKrw").value(12_000))
			.andExpect(jsonPath("$.shareKrw").value(25_069))
			.andExpect(jsonPath("$.balanceKrw").value(-13_069))
			.andExpect(jsonPath("$.status").value("SEND"))
			.andExpect(jsonPath("$.tripTotalKrw").value(87_348))
			.andExpect(jsonPath("$.expenses.length()").value(3))
			.andExpect(jsonPath("$.expenses[0].myShareKrw").value(9_069))
			.andExpect(jsonPath("$.transfers[0].direction").value("SEND"));

		// 4번은 분담만 한 지출 1건
		perform(get("/api/trips/" + trip.getId() + "/settlement/me"), 4, null)
			.andExpect(jsonPath("$.expenses.length()").value(1))
			.andExpect(jsonPath("$.expenses[0].balanceKrw").value(-9_069))
			.andExpect(jsonPath("$.transfers[0].amountKrw").value(9_069));
	}

	private ResultActions perform(MockHttpServletRequestBuilder request, int member, String body) throws Exception {
		request.header(HttpHeaders.AUTHORIZATION, "Bearer " + tokens.get(member));
		if (body != null) {
			request.contentType(MediaType.APPLICATION_JSON).content(body);
		}
		return mockMvc.perform(request);
	}

	private String expensesUrl() {
		return "/api/trips/" + trip.getId() + "/expenses";
	}

	private String id(int member) {
		return members.get(member).getId().toString();
	}

	private String equalBody(int payer, String rateMode, String amountLocal, LocalDate paidDate, int... targets) {
		return """
			{"payerMemberId":"%s","title":"구로몬 시장","category":"FOOD","paidDate":"%s","rateMode":"%s",
			 "amountLocal":%s,"splitMethod":"EQUAL","memberIds":[%s]}
			""".formatted(id(payer), paidDate, rateMode, amountLocal, ids(targets));
	}

	private String krwEqualBody(int payer, long amountKrw, int... targets) {
		return """
			{"payerMemberId":"%s","title":"택시","category":"TRANSPORT","paidDate":"%s","rateMode":"KRW",
			 "amountKrw":%d,"splitMethod":"EQUAL","memberIds":[%s]}
			""".formatted(id(payer), DAY1, amountKrw, ids(targets));
	}

	private String ids(int... targets) {
		List<String> quoted = new ArrayList<>();
		for (int target : targets) {
			quoted.add("\"" + id(target) + "\"");
		}
		return String.join(",", quoted);
	}

	private static ExchangeRate rate(String code, LocalDate date, String value) {
		return ExchangeRate.builder().currencyCode(code).rateDate(date).rateToKrw(new BigDecimal(value)).build();
	}
}
