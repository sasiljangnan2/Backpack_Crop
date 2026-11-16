package com.backpackcorp.backpack.schedule;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.support.ApiTestSupport;

import jakarta.persistence.EntityManager;
import org.springframework.beans.factory.annotation.Autowired;

// 예약 시간 · 상태 (BP-SC-002 ⑤), 예약 결제를 지출과 잇기 (BP-SC-001 ⑥ · 002 ⑥ · 003 ④)
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ScheduleReservationApiTest extends ApiTestSupport {

	private static final LocalDate DAY = LocalDate.of(2026, 10, 3);

	@Autowired
	private EntityManager entityManager;

	@BeforeEach
	void setUp() {
		setUpTrip(DAY, DAY.plusDays(2), "JPY", "김방장", "이멤버");
	}

	@Test
	void 예약_전_상태와_예약_시간을_저장하고_예약을_없애면_시간도_지운다() throws Exception {
		String id = read(create("BEFORE", "\"18:30\"")
			.andExpect(jsonPath("$.reservationStatus").value("BEFORE"))
			.andExpect(jsonPath("$.reservationTime").value("18:30"))
			.andExpect(jsonPath("$.linkedExpenseId").doesNotExist()), "$.id");

		perform(patch(schedule(id)), 0, """
			{"version":0,"reservationStatus":"CONFIRMED","reservationTime":"19:00"}
			""")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.reservationStatus").value("CONFIRMED"))
			.andExpect(jsonPath("$.reservationTime").value("19:00"));
		// 고정만 바꾸면 예약은 그대로다
		perform(patch(schedule(id)), 0, """
			{"version":1,"isLocked":true}
			""")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.reservationTime").value("19:00"));
		perform(patch(schedule(id)), 0, """
			{"version":2,"isLocked":false}
			""").andExpect(status().isOk());
		perform(patch(schedule(id)), 0, """
			{"version":3,"reservationStatus":"NONE","reservationTime":"19:00"}
			""")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.reservationStatus").value("NONE"))
			.andExpect(jsonPath("$.reservationTime").doesNotExist());
	}

	@Test
	void 예약이_없으면_시간을_보내도_저장하지_않는다() throws Exception {
		create("NONE", "\"18:30\"")
			.andExpect(jsonPath("$.reservationStatus").value("NONE"))
			.andExpect(jsonPath("$.reservationTime").doesNotExist());
	}

	@Test
	void 예약_결제를_지출로_등록하면_일정에_연결되고_일정을_지워도_지출은_남는다() throws Exception {
		String scheduleId = read(create("CONFIRMED", "\"18:30\""), "$.id");

		String expenseId = read(perform(post(tripUrl() + "/expenses"), 0, expenseBody(scheduleId))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.scheduleId").value(scheduleId)), "$.id");
		entityManager.flush();
		entityManager.clear();

		perform(get(tripUrl() + "/schedules"), 1, null)
			.andExpect(jsonPath("$[0].linkedExpenseId").value(expenseId));
		perform(get(schedule(scheduleId)), 1, null)
			.andExpect(jsonPath("$.linkedExpenseId").value(expenseId));

		perform(delete(schedule(scheduleId)), 0, null).andExpect(status().isNoContent());
		entityManager.flush();
		entityManager.clear();

		perform(get(tripUrl() + "/expenses/" + expenseId), 0, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.scheduleId").doesNotExist());
	}

	@Test
	void 다른_여행의_일정은_지출에_연결할_수_없다() throws Exception {
		perform(post(tripUrl() + "/expenses"), 0, expenseBody(UUID.randomUUID().toString()))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("INVALID_EXPENSE"));
	}

	private ResultActions create(String reservation, String time) throws Exception {
		return perform(post(tripUrl() + "/schedules"), 0, """
			{"day":"%s","startTime":"18:00","endTime":"20:00","title":"저녁 예약",
			 "reservationStatus":"%s","reservationTime":%s}
			""".formatted(DAY, reservation, time))
			.andExpect(status().isCreated());
	}

	private String expenseBody(String scheduleId) {
		return """
			{"payerMemberId":"%s","scheduleId":"%s","title":"저녁 예약 결제","category":"FOOD","paidDate":"%s",
			 "rateMode":"KRW","amountKrw":10000,"splitMethod":"EQUAL","memberIds":["%s"]}
			""".formatted(id(0), scheduleId, DAY, id(0));
	}

	private String schedule(String id) {
		return tripUrl() + "/schedules/" + id;
	}
}
