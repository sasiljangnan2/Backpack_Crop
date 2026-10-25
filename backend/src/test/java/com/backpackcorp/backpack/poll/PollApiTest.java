package com.backpackcorp.backpack.poll;

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

// 지금은 2026-10-03 14:50 (도쿄)
@SpringBootTest(properties = "app.demo.now=2026-10-03T05:50:00Z")
@ActiveProfiles("test")
@Transactional
class PollApiTest extends ApiTestSupport {

	private static final LocalDate DAY = LocalDate.of(2026, 10, 3);

	@BeforeEach
	void setUp() {
		setUpTrip(DAY.minusDays(1), DAY.plusDays(2), "JPY", "김방장", "이멤버", "박멤버");
	}

	@Test
	void 투표를_만들고_1인_1표로_투표하고_바꿀_수_있다() throws Exception {
		ResultActions created = createPoll(1, null).andExpect(status().isCreated())
			.andExpect(jsonPath("$.options.length()").value(3))
			.andExpect(jsonPath("$.isVotingOpen").value(true))
			.andExpect(jsonPath("$.memberCount").value(3))
			.andExpect(jsonPath("$.canManage").value(true));
		String pollId = read(created, "$.id");
		String ramen = read(created, "$.options[0].id");
		String sushi = read(created, "$.options[1].id");

		vote(0, pollId, ramen).andExpect(jsonPath("$.myOptionId").value(ramen));
		vote(2, pollId, ramen);
		vote(2, pollId, sushi)
			.andExpect(jsonPath("$.voteCount").value(2))
			.andExpect(jsonPath("$.options[0].voteCount").value(1))
			.andExpect(jsonPath("$.options[1].voters[0].name").value("박멤버"))
			.andExpect(jsonPath("$.options[0].isLeading").value(true))
			.andExpect(jsonPath("$.options[1].isLeading").value(true))
			.andExpect(jsonPath("$.canManage").value(false));

		perform(delete(tripUrl() + "/polls/" + pollId + "/votes/me"), 2, null).andExpect(status().isNoContent());
		perform(get(tripUrl() + "/polls/" + pollId), 2, null)
			.andExpect(jsonPath("$.voteCount").value(1))
			.andExpect(jsonPath("$.myOptionId").doesNotExist());
		perform(get(tripUrl() + "/polls").param("status", "OPEN"), 2, null).andExpect(jsonPath("$.length()").value(1));
	}

	@Test
	void 마감하면서_후보를_고르면_슬롯에_일정이_생긴다() throws Exception {
		ResultActions created = createPoll(1, null);
		String pollId = read(created, "$.id");
		String ramen = read(created, "$.options[0].id");

		perform(post(tripUrl() + "/polls/" + pollId + "/close"), 2, "{\"selectedOptionId\":\"%s\"}".formatted(ramen))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("NOT_POLL_MANAGER"));
		perform(post(tripUrl() + "/polls/" + pollId + "/close"), 1, "{\"selectedOptionId\":\"%s\"}".formatted(ramen))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.status").value("CLOSED"))
			.andExpect(jsonPath("$.selectedOptionId").value(ramen))
			.andExpect(jsonPath("$.scheduleId").exists())
			.andExpect(jsonPath("$.isVotingOpen").value(false));

		perform(get(tripUrl() + "/schedules").param("day", DAY.plusDays(1).toString()), 0, null)
			.andExpect(jsonPath("$[0].title").value("이치란 라멘"))
			.andExpect(jsonPath("$[0].startTime").value("18:30"));
		vote(0, pollId, ramen).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("POLL_CLOSED"));
		perform(post(tripUrl() + "/polls/" + pollId + "/close"), 1, null).andExpect(status().isConflict());
	}

	@Test
	void 슬롯이_다른_일정과_겹치면_마감할_수_없다() throws Exception {
		perform(post(tripUrl() + "/schedules"), 0, """
			{"day":"%s","startTime":"18:00","endTime":"19:00","title":"야경"}
			""".formatted(DAY.plusDays(1))).andExpect(status().isCreated());
		ResultActions created = createPoll(1, null);

		perform(post(tripUrl() + "/polls/" + read(created, "$.id") + "/close"), 0,
			"{\"selectedOptionId\":\"%s\"}".formatted(read(created, "$.options[0].id")))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("SCHEDULE_OVERLAP"));
	}

	@Test
	void 마감_시각이_지나면_투표를_받지_않는다() throws Exception {
		createPoll(1, "2026-10-03T05:40:00Z").andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.deadlineAt").exists());
		ResultActions created = createPoll(1, "2026-10-03T06:00:00Z").andExpect(status().isCreated());

		vote(0, read(created, "$.id"), read(created, "$.options[0].id")).andExpect(status().isOk());
	}

	@Test
	void 후보가_하나뿐이거나_여행_기간_밖이면_400이다() throws Exception {
		perform(post(tripUrl() + "/polls"), 0, """
			{"title":"x","slotDate":"%s","slotStart":"18:30","slotEnd":"20:00","options":[{"label":"하나"}]}
			""".formatted(DAY)).andExpect(status().isBadRequest()).andExpect(jsonPath("$.details.options").exists());
		perform(post(tripUrl() + "/polls"), 0, """
			{"title":"x","slotDate":"2026-12-01","slotStart":"18:30","slotEnd":"20:00",
			 "options":[{"label":"a"},{"label":"b"}]}
			""").andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("SCHEDULE_OUT_OF_TRIP"));
	}

	@Test
	void 방장은_남이_만든_투표를_지울_수_있다() throws Exception {
		String pollId = read(createPoll(1, null), "$.id");

		perform(delete(tripUrl() + "/polls/" + pollId), 2, null).andExpect(status().isForbidden());
		perform(delete(tripUrl() + "/polls/" + pollId), 0, null).andExpect(status().isNoContent());
		perform(get(tripUrl() + "/polls/" + pollId), 0, null).andExpect(status().isNotFound());
	}

	private ResultActions createPoll(int member, String deadline) throws Exception {
		String deadlineJson = deadline == null ? "null" : "\"" + deadline + "\"";
		return perform(post(tripUrl() + "/polls"), member, """
			{"title":"둘째 날 저녁","slotDate":"%s","slotStart":"18:30","slotEnd":"20:00","deadlineAt":%s,
			 "options":[{"label":"이치란 라멘","memo":"도보 5분"},{"label":"회전 초밥"},{"label":"오코노미야키"}]}
			""".formatted(DAY.plusDays(1), deadlineJson));
	}

	private ResultActions vote(int member, String pollId, String optionId) throws Exception {
		return perform(put(tripUrl() + "/polls/" + pollId + "/votes/me"), member,
			"{\"optionId\":\"%s\"}".formatted(optionId));
	}
}
