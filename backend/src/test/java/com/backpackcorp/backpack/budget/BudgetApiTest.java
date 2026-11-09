package com.backpackcorp.backpack.budget;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.LocalDate;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.budget.domain.ExchangeRate;
import com.backpackcorp.backpack.budget.repository.ExchangeRateRepository;
import com.backpackcorp.backpack.support.ApiTestSupport;

// 오늘(한국) 2026-10-03, 엔화 환율 9.35
@SpringBootTest(properties = "app.demo.now=2026-10-03T05:50:00Z")
@ActiveProfiles("test")
@Transactional
class BudgetApiTest extends ApiTestSupport {

	private static final LocalDate DAY = LocalDate.of(2026, 10, 3);

	@Autowired
	private ExchangeRateRepository exchangeRateRepository;

	@BeforeEach
	void setUp() {
		setUpTrip(DAY, DAY.plusDays(2), "JPY", "김방장", "이멤버", "박멤버");
		exchangeRateRepository.save(ExchangeRate.builder().currencyCode("JPY").rateDate(DAY)
			.rateToKrw(new BigDecimal("9.350000")).build());
	}

	@Test
	void 예산은_원화로_모아_분류별_지출과_비교하고_1인_금액을_준다() throws Exception {
		item("LODGING", "호텔 2박", "400000", "KRW").andExpect(status().isCreated())
			.andExpect(jsonPath("$.amountKrw").value(400_000));
		item("FOOD", "식비", "30000", "JPY").andExpect(jsonPath("$.amountKrw").value(280_500));
		perform(post(tripUrl() + "/expenses"), 0, """
			{"payerMemberId":"%s","title":"라멘","category":"FOOD","paidDate":"%s","rateMode":"KRW",
			 "amountKrw":12000,"splitMethod":"EQUAL","memberIds":["%s"]}
			""".formatted(id(0), DAY, id(0))).andExpect(status().isCreated());

		perform(get(tripUrl() + "/budget-items"), 1, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.items.length()").value(2))
			.andExpect(jsonPath("$.totalBudgetKrw").value(680_500))
			.andExpect(jsonPath("$.totalSpentKrw").value(12_000))
			.andExpect(jsonPath("$.memberCount").value(3))
			.andExpect(jsonPath("$.perPersonBudgetKrw").value(226_834))
			.andExpect(jsonPath("$.todayRate.rateToKrw").value(9.35))
			.andExpect(jsonPath("$.hasUnconvertedItems").value(false))
			.andExpect(jsonPath("$.summary[?(@.category == 'FOOD')].spentKrw").value(12_000))
			.andExpect(jsonPath("$.summary[?(@.category == 'FOOD')].budgetKrw").value(280_500));
	}

	@Test
	void 항목을_고치고_지울_수_있다() throws Exception {
		String itemId = read(item("ETC", "유심", "30000", "KRW"), "$.id");

		perform(patch(tripUrl() + "/budget-items/" + itemId), 1, "{\"amount\":3000,\"currencyCode\":\"jpy\"}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.currencyCode").value("JPY"))
			.andExpect(jsonPath("$.amountKrw").value(28_050));
		perform(delete(tripUrl() + "/budget-items/" + itemId), 2, null).andExpect(status().isNoContent());
		perform(get(tripUrl() + "/budget-items"), 0, null).andExpect(jsonPath("$.totalBudgetKrw").value(0));
	}

	@Test
	void 원화와_여행_통화가_아닌_통화는_받지_않는다() throws Exception {
		item("FOOD", "식비", "100", "USD")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.currencyCode").exists());
		item("FOOD", "", "-1", "KRW")
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.name").exists())
			.andExpect(jsonPath("$.details.amount").exists());
	}

	private org.springframework.test.web.servlet.ResultActions item(String category, String name, String amount,
		String currency) throws Exception {
		return perform(post(tripUrl() + "/budget-items"), 0,
			"{\"category\":\"%s\",\"name\":\"%s\",\"amount\":%s,\"currencyCode\":\"%s\"}"
				.formatted(category, name, amount, currency));
	}
}
