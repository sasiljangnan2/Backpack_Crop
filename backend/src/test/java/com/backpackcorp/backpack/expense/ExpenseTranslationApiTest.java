package com.backpackcorp.backpack.expense;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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

// 외국어 영수증에서 읽은 가게 · 항목 이름의 한국어 번역을 지출과 함께 저장하고 보여 준다 (BP-EX-003)
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ExpenseTranslationApiTest extends ApiTestSupport {

	private static final LocalDate DAY = LocalDate.of(2026, 3, 8);

	@Autowired
	private ExchangeRateRepository exchangeRateRepository;

	@BeforeEach
	void setUp() {
		setUpTrip(DAY, DAY.plusDays(2), "JPY", "김방장", "이멤버");
		exchangeRateRepository.save(ExchangeRate.builder().currencyCode("JPY").rateDate(DAY)
			.rateToKrw(new BigDecimal("9.350000")).build());
	}

	@Test
	void 번역은_상세와_목록에_함께_나오고_수정하면_바뀐다() throws Exception {
		String id = read(perform(post(tripUrl() + "/expenses"), 0, body("\"세븐일레븐 다카마쓰역점\"", "\"치킨 난반\"", null))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.titleKo").value("세븐일레븐 다카마쓰역점"))
			.andExpect(jsonPath("$.items[0].nameKo").value("치킨 난반"))
			// 빈 번역은 저장하지 않는다
			.andExpect(jsonPath("$.items[1].nameKo").doesNotExist()), "$.id");

		perform(get(tripUrl() + "/expenses/" + id), 1, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.title").value("セブン-イレブン 高松駅店"))
			.andExpect(jsonPath("$.titleKo").value("세븐일레븐 다카마쓰역점"))
			.andExpect(jsonPath("$.items[0].name").value("チキン南蛮"))
			.andExpect(jsonPath("$.items[0].nameKo").value("치킨 난반"));
		perform(get(tripUrl() + "/expenses"), 1, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.content[0].titleKo").value("세븐일레븐 다카마쓰역점"));

		// 번역 없이 수정하면 번역도 지운다 (이름을 고치면 번역이 맞지 않으므로 앱이 보내지 않는다)
		perform(put(tripUrl() + "/expenses/" + id), 0, body(null, null, 0))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.titleKo").doesNotExist())
			.andExpect(jsonPath("$.items[0].nameKo").doesNotExist());
	}

	private String body(String titleKo, String firstNameKo, Integer version) {
		return """
			{"payerMemberId":"%s","title":"セブン-イレブン 高松駅店","titleKo":%s,"category":"FOOD","paidDate":"%s",
			 "rateMode":"API","amountLocal":1018,"splitMethod":"ITEM","version":%s,
			 "items":[{"name":"チキン南蛮","nameKo":%s,"amountLocal":298,"members":[{"memberId":"%s"},{"memberId":"%s"}]},
			          {"name":"弁当","nameKo":"  ","amountLocal":720,"members":[{"memberId":"%s"}]}]}
			""".formatted(id(0), titleKo, DAY, version, firstNameKo, id(0), id(1), id(1));
	}
}
