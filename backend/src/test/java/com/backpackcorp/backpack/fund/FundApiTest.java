package com.backpackcorp.backpack.fund;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.support.ApiTestSupport;

// 공금: 멤버가 돈을 모아 두고 지출을 거기서 낸다. 예산에서 잔액을 보고, 남은 공금은 정산에서 돌려받는다
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class FundApiTest extends ApiTestSupport {

	private static final LocalDate DAY = LocalDate.of(2026, 10, 3);

	@BeforeEach
	void setUp() {
		setUpTrip(DAY, DAY.plusDays(2), "JPY", "김방장", "이멤버");
	}

	@Test
	void 공금에서_내면_잔액이_줄고_남은_공금은_낸_사람에게_돌아간다() throws Exception {
		contribute(0, 150_000);
		contribute(1, 50_000);
		perform(get(fund()), 1, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.collectedKrw").value(200_000))
			.andExpect(jsonPath("$.spentKrw").value(0))
			.andExpect(jsonPath("$.remainingKrw").value(200_000))
			.andExpect(jsonPath("$.members[0].contributedKrw").value(150_000))
			.andExpect(jsonPath("$.members[1].contributedKrw").value(50_000))
			.andExpect(jsonPath("$.contributions.length()").value(2));

		perform(post(tripUrl() + "/expenses"), 0, fundExpense("저녁", 60_000, null))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.paidFromFund").value(true))
			.andExpect(jsonPath("$.payer.name").value("공금"))
			.andExpect(jsonPath("$.creator.name").value("김방장"))
			.andExpect(jsonPath("$.memberShares[?(@.isPayer == true)]").isEmpty());

		perform(get(fund()), 0, null)
			.andExpect(jsonPath("$.spentKrw").value(60_000))
			.andExpect(jsonPath("$.remainingKrw").value(140_000));
		// 예산 화면에서 지금 금액과 비교한다
		perform(get(tripUrl() + "/budget-items"), 0, null)
			.andExpect(jsonPath("$.totalSpentKrw").value(60_000))
			.andExpect(jsonPath("$.fund.collectedKrw").value(200_000))
			.andExpect(jsonPath("$.fund.remainingKrw").value(140_000));
		perform(get(tripUrl() + "/expenses"), 0, null)
			.andExpect(jsonPath("$.content[0].paidFromFund").value(true))
			.andExpect(jsonPath("$.content[0].payer.name").value("공금"))
			.andExpect(jsonPath("$.content[0].isPaidByMe").value(false))
			.andExpect(jsonPath("$.content[0].myShareKrw").value(30_000));

		// 각자 30,000원씩 썼으니 모은 돈에서 뺀 만큼 돌려받는다: 120,000 + 20,000 = 남은 공금 140,000
		perform(get(tripUrl() + "/settlement"), 0, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.totalKrw").value(60_000))
			.andExpect(jsonPath("$.fund.remainingKrw").value(140_000))
			.andExpect(jsonPath("$.members.length()").value(2))
			.andExpect(jsonPath("$.members[0].paidKrw").value(150_000))
			.andExpect(jsonPath("$.members[0].contributedKrw").value(150_000))
			.andExpect(jsonPath("$.members[0].shareKrw").value(30_000))
			.andExpect(jsonPath("$.members[0].balanceKrw").value(120_000))
			.andExpect(jsonPath("$.members[1].balanceKrw").value(20_000))
			.andExpect(jsonPath("$.transfers.length()").value(2))
			.andExpect(jsonPath("$.transfers[0].from.name").value("공금"))
			.andExpect(jsonPath("$.transfers[0].to.name").value("김방장"))
			.andExpect(jsonPath("$.transfers[0].amountKrw").value(120_000))
			.andExpect(jsonPath("$.transfers[1].to.name").value("이멤버"))
			.andExpect(jsonPath("$.transfers[1].amountKrw").value(20_000));
		perform(get(tripUrl() + "/settlement/me"), 1, null)
			.andExpect(jsonPath("$.contributedKrw").value(50_000))
			.andExpect(jsonPath("$.tripTotalKrw").value(60_000))
			.andExpect(jsonPath("$.transfers[0].direction").value("RECEIVE"))
			.andExpect(jsonPath("$.transfers[0].counterpart.name").value("공금"))
			.andExpect(jsonPath("$.transfers[0].amountKrw").value(20_000))
			.andExpect(jsonPath("$.expenses[0].payer.name").value("공금"))
			.andExpect(jsonPath("$.expenses[0].isPaidByMe").value(false));
	}

	@Test
	void 사람이_낸_지출과_섞여도_받을_돈과_남은_공금이_맞는다() throws Exception {
		contribute(0, 100_000);
		contribute(1, 100_000);
		perform(post(tripUrl() + "/expenses"), 0, fundExpense("저녁", 60_000, null)).andExpect(status().isCreated());
		// 김방장이 40,000원을 직접 내고 둘이 나눈다
		perform(post(tripUrl() + "/expenses"), 0, """
			{"payerMemberId":"%s","title":"택시","category":"TRANSPORT","paidDate":"%s","rateMode":"KRW",
			 "amountKrw":40000,"splitMethod":"EQUAL","memberIds":["%s","%s"]}
			""".formatted(id(0), DAY, id(0), id(1))).andExpect(status().isCreated());

		// 김방장: 100,000 + 40,000 - 30,000 - 20,000 = 90,000 / 이멤버: 100,000 - 30,000 - 20,000 = 50,000
		perform(get(tripUrl() + "/settlement"), 0, null)
			.andExpect(jsonPath("$.totalKrw").value(100_000))
			.andExpect(jsonPath("$.fund.remainingKrw").value(140_000))
			.andExpect(jsonPath("$.members[0].balanceKrw").value(90_000))
			.andExpect(jsonPath("$.members[1].balanceKrw").value(50_000))
			.andExpect(jsonPath("$.transfers[0].from.name").value("공금"))
			.andExpect(jsonPath("$.transfers[0].amountKrw").value(90_000))
			.andExpect(jsonPath("$.transfers[1].amountKrw").value(50_000));
	}

	@Test
	void 공금을_쓰지_않는_여행의_정산은_그대로다() throws Exception {
		perform(post(tripUrl() + "/expenses"), 0, """
			{"payerMemberId":"%s","title":"택시","category":"TRANSPORT","paidDate":"%s","rateMode":"KRW",
			 "amountKrw":40000,"splitMethod":"EQUAL","memberIds":["%s","%s"]}
			""".formatted(id(0), DAY, id(0), id(1))).andExpect(status().isCreated());

		perform(get(tripUrl() + "/settlement"), 0, null)
			.andExpect(jsonPath("$.fund").doesNotExist())
			.andExpect(jsonPath("$.totalKrw").value(40_000))
			.andExpect(jsonPath("$.members.length()").value(2))
			.andExpect(jsonPath("$.transfers.length()").value(1))
			.andExpect(jsonPath("$.transfers[0].from.name").value("이멤버"))
			.andExpect(jsonPath("$.transfers[0].to.name").value("김방장"))
			.andExpect(jsonPath("$.transfers[0].amountKrw").value(20_000));
	}

	@Test
	void 잔액보다_큰_공금_지출은_막고_수정은_자기_금액을_빼고_본다() throws Exception {
		contribute(0, 100_000);
		perform(post(tripUrl() + "/expenses"), 0, fundExpense("호텔", 100_001, null))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("FUND_INSUFFICIENT"));

		String expenseId = read(perform(post(tripUrl() + "/expenses"), 0, fundExpense("호텔", 80_000, null))
			.andExpect(status().isCreated()), "$.id");
		// 미리보기는 금액만 계산한다 (잔액 안내는 앱이 한다)
		perform(post(tripUrl() + "/expenses/preview"), 0, fundExpense("호텔", 100_001, null))
			.andExpect(status().isOk());

		perform(put(tripUrl() + "/expenses/" + expenseId), 0, fundExpense("호텔", 100_000, 0))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.amountKrw").value(100_000));
		perform(put(tripUrl() + "/expenses/" + expenseId), 0, fundExpense("호텔", 100_001, 1))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("FUND_INSUFFICIENT"));
	}

	@Test
	void 이미_쓴_공금보다_모은_돈을_줄이거나_지울_수_없다() throws Exception {
		String contribution = read(contribute(0, 100_000), "$.contributions[0].id");
		perform(post(tripUrl() + "/expenses"), 0, fundExpense("호텔", 80_000, null)).andExpect(status().isCreated());

		perform(put(fund() + "/contributions/" + contribution), 0, contributionBody(0, 79_999))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("FUND_INSUFFICIENT"));
		perform(delete(fund() + "/contributions/" + contribution), 0, null)
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("FUND_INSUFFICIENT"));

		perform(put(fund() + "/contributions/" + contribution), 0, contributionBody(0, 80_000))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.remainingKrw").value(0));
	}

	@Test
	void 수정은_낸_사람_입력한_사람_방장만_할_수_있다() throws Exception {
		setUpThirdMember();
		String byHostForHost = read(contribute(0, 10_000), "$.contributions[0].id");
		perform(get(fund()), 2, null)
			.andExpect(jsonPath("$.contributions[0].canEdit").value(false));
		perform(delete(fund() + "/contributions/" + byHostForHost), 2, null)
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("NOT_FUND_EDITOR"));

		// 이멤버가 박멤버의 돈을 대신 적으면 셋 다 고칠 수 있다
		String forOther = read(perform(post(fund() + "/contributions"), 1, contributionBody(2, 5_000))
			.andExpect(status().isCreated()), "$.contributions[0].id");
		perform(delete(fund() + "/contributions/" + forOther), 2, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.collectedKrw").value(10_000));
		perform(delete(fund() + "/contributions/" + byHostForHost), 0, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.collectedKrw").value(0));
	}

	@Test
	void 공금_지출은_결제자_환전_환율을_쓸_수_없고_멤버만_공금을_넣을_수_있다() throws Exception {
		contribute(0, 100_000);
		perform(post(tripUrl() + "/expenses"), 0, """
			{"payerMemberId":"%s","paidFromFund":true,"title":"호텔","category":"LODGING","paidDate":"%s",
			 "rateMode":"PREPAID","amountLocal":1000,"splitMethod":"EQUAL","memberIds":["%s"]}
			""".formatted(id(0), DAY, id(0)))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("INVALID_EXPENSE"));

		perform(post(fund() + "/contributions"), 0, """
			{"memberId":"00000000-0000-0000-0000-000000000001","amountKrw":1000}
			""")
			.andExpect(status().isBadRequest());
		perform(post(fund() + "/contributions"), 0, """
			{"memberId":"%s","amountKrw":0}
			""".formatted(id(0)))
			.andExpect(status().isBadRequest());
	}

	@Test
	void 정산_공유에도_남은_공금이_남는다() throws Exception {
		contribute(0, 100_000);
		perform(post(tripUrl() + "/expenses"), 0, fundExpense("저녁", 60_000, null)).andExpect(status().isCreated());

		String shareId = read(perform(post(tripUrl() + "/settlement-shares"), 0, null)
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.transfers[0].from.name").value("공금")), "$.id");

		perform(get(tripUrl() + "/settlement-shares/" + shareId), 1, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.transfers.length()").value(2));
		perform(get(tripUrl() + "/settlement-shares"), 0, null)
			.andExpect(jsonPath("$[0].transferCount").value(2));
	}

	private void setUpThirdMember() {
		var user = userRepository.save(com.backpackcorp.backpack.user.domain.User.builder().email("s2@b.c")
			.passwordHash("{noop}x").name("박멤버").build());
		users.add(user);
		members.add(tripMemberRepository.save(com.backpackcorp.backpack.trip.domain.TripMember.builder().trip(trip)
			.user(user).role(com.backpackcorp.backpack.trip.domain.TripMemberRole.MEMBER).build()));
		tokens.add(tokenService.createAccessToken(user.getId(), com.backpackcorp.backpack.user.domain.Role.USER));
	}

	private ResultActions contribute(int member, long amount) throws Exception {
		return perform(post(fund() + "/contributions"), member, contributionBody(member, amount))
			.andExpect(status().isCreated());
	}

	private String contributionBody(int member, long amount) {
		return """
			{"memberId":"%s","amountKrw":%d,"contributedOn":"%s","memo":"첫 모임"}
			""".formatted(id(member), amount, DAY);
	}

	private String fundExpense(String title, long amount, Integer version) {
		return """
			{"payerMemberId":"%s","paidFromFund":true,"title":"%s","category":"FOOD","paidDate":"%s","rateMode":"KRW",
			 "amountKrw":%d,"splitMethod":"EQUAL","memberIds":["%s","%s"],"version":%s}
			""".formatted(id(0), title, DAY, amount, id(0), id(1), version);
	}

	private String fund() {
		return tripUrl() + "/fund";
	}
}
