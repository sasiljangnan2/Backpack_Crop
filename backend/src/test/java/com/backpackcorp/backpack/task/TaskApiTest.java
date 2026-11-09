package com.backpackcorp.backpack.task;

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
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.support.ApiTestSupport;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class TaskApiTest extends ApiTestSupport {

	@BeforeEach
	void setUp() {
		setUpTrip(LocalDate.of(2026, 10, 3), LocalDate.of(2026, 10, 5), "JPY", "김방장", "이멤버", "박멤버");
	}

	@Test
	void 함께_할_업무는_모두가_보고_개인_업무는_만든_사람만_본다() throws Exception {
		create(0, "TEAM", "숙소 예약", id(1)).andExpect(status().isCreated())
			.andExpect(jsonPath("$.assignee.name").value("이멤버"))
			.andExpect(jsonPath("$.isDone").value(false));
		// 개인 업무에 담당자를 보내도 무시하고 나로 정한다
		create(1, "PRIVATE", "여권 챙기기", id(2)).andExpect(jsonPath("$.assignee.memberId").value(id(1)));

		perform(get(tripUrl() + "/tasks"), 1, null).andExpect(jsonPath("$.length()").value(2));
		perform(get(tripUrl() + "/tasks"), 2, null)
			.andExpect(jsonPath("$.length()").value(1))
			.andExpect(jsonPath("$[0].title").value("숙소 예약"));
		perform(get(tripUrl() + "/tasks").param("scope", "PRIVATE"), 1, null)
			.andExpect(jsonPath("$.length()").value(1));
	}

	@Test
	void 완료_체크와_담당자_변경() throws Exception {
		String taskId = read(create(0, "TEAM", "환전하기", null), "$.id");

		perform(patch(tripUrl() + "/tasks/" + taskId), 2, "{\"isDone\":true,\"assigneeMemberId\":\"%s\"}"
			.formatted(id(2)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.isDone").value(true))
			.andExpect(jsonPath("$.assignee.memberId").value(id(2)))
			.andExpect(jsonPath("$.isMine").value(true));
		perform(patch(tripUrl() + "/tasks/" + taskId), 0, "{\"clearAssignee\":true,\"title\":\"엔화 환전\"}")
			.andExpect(jsonPath("$.assignee").doesNotExist())
			.andExpect(jsonPath("$.title").value("엔화 환전"));
		// 완료된 업무는 목록 뒤로 간다
		create(0, "TEAM", "유심 사기", null);
		perform(get(tripUrl() + "/tasks"), 0, null).andExpect(jsonPath("$[0].title").value("유심 사기"));
	}

	@Test
	void 남의_개인_업무는_찾을_수_없고_다른_여행_멤버에게는_맡길_수_없다() throws Exception {
		String privateId = read(create(1, "PRIVATE", "여권 챙기기", null), "$.id");

		perform(patch(tripUrl() + "/tasks/" + privateId), 0, "{\"isDone\":true}").andExpect(status().isNotFound());
		perform(delete(tripUrl() + "/tasks/" + privateId), 0, null).andExpect(status().isNotFound());
		create(0, "TEAM", "x", UUID.randomUUID().toString())
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.details.assigneeMemberId").exists());
	}

	@Test
	void 함께_할_업무는_만든_사람_담당자_방장만_지운다() throws Exception {
		String taskId = read(create(1, "TEAM", "렌터카 예약", id(1)), "$.id");

		perform(delete(tripUrl() + "/tasks/" + taskId), 2, null)
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("NOT_TASK_OWNER"));
		perform(delete(tripUrl() + "/tasks/" + taskId), 0, null).andExpect(status().isNoContent());
		perform(get(tripUrl() + "/tasks"), 1, null).andExpect(jsonPath("$.length()").value(0));
	}

	@Test
	void 마감일과_진행_상태_마감_순_정렬() throws Exception {
		perform(post(tripUrl() + "/tasks"), 0,
			"{\"scope\":\"TEAM\",\"title\":\"보험 가입\",\"assigneeMemberId\":\"%s\",\"dueDate\":\"2026-09-30\"}"
				.formatted(id(1)))
			.andExpect(jsonPath("$.dueDate").value("2026-09-30"))
			.andExpect(jsonPath("$.status").value("TODO"));
		String passId = read(perform(post(tripUrl() + "/tasks"), 0,
			"{\"scope\":\"TEAM\",\"title\":\"주유패스 구매\",\"dueDate\":\"2026-09-28\",\"status\":\"IN_PROGRESS\"}"),
			"$.id");
		create(0, "TEAM", "마감일 없음", null);

		// 마감이 빠른 순, 마감일 없는 업무는 뒤
		perform(get(tripUrl() + "/tasks"), 0, null)
			.andExpect(jsonPath("$[0].title").value("주유패스 구매"))
			.andExpect(jsonPath("$[0].status").value("IN_PROGRESS"))
			.andExpect(jsonPath("$[0].isDone").value(false))
			.andExpect(jsonPath("$[1].title").value("보험 가입"))
			.andExpect(jsonPath("$[2].title").value("마감일 없음"));

		// 완료로 바꾸면 isDone도 함께 바뀌고, 다시 체크를 풀면 할 일로 돌아간다
		perform(patch(tripUrl() + "/tasks/" + passId), 0, "{\"status\":\"DONE\"}")
			.andExpect(jsonPath("$.status").value("DONE"))
			.andExpect(jsonPath("$.isDone").value(true));
		perform(patch(tripUrl() + "/tasks/" + passId), 0, "{\"isDone\":false,\"clearDueDate\":true}")
			.andExpect(jsonPath("$.status").value("TODO"))
			.andExpect(jsonPath("$.dueDate").doesNotExist());
	}

	private org.springframework.test.web.servlet.ResultActions create(int member, String scope, String title,
		String assignee) throws Exception {
		String assigneeJson = assignee == null ? "null" : "\"" + assignee + "\"";
		return perform(post(tripUrl() + "/tasks"), member,
			"{\"scope\":\"%s\",\"title\":\"%s\",\"assigneeMemberId\":%s}".formatted(scope, title, assigneeJson));
	}
}
