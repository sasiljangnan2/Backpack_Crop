package com.backpackcorp.backpack.notification;

import static org.assertj.core.api.Assertions.assertThat;
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
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.notification.repository.DeviceTokenRepository;
import com.backpackcorp.backpack.notification.repository.NotificationRepository;
import com.backpackcorp.backpack.support.ApiTestSupport;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class NotificationApiTest extends ApiTestSupport {

	private static final LocalDate DAY = LocalDate.of(2026, 10, 3);

	@Autowired
	private NotificationRepository notificationRepository;
	@Autowired
	private DeviceTokenRepository deviceTokenRepository;

	@BeforeEach
	void setUp() {
		setUpTrip(DAY, DAY.plusDays(2), "KRW", "김방장", "이멤버", "박멤버");
	}

	@Test
	void 지출을_등록하면_본인을_뺀_멤버에게_알림이_가고_읽음_처리할_수_있다() throws Exception {
		addExpense(1);

		perform(get("/api/notifications"), 0, null)
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.content.length()").value(1))
			.andExpect(jsonPath("$.content[0].type").value("EXPENSE_ADDED"))
			.andExpect(jsonPath("$.content[0].message").value("이멤버님이 '택시' 지출을 추가했어요 · ₩12,000"))
			.andExpect(jsonPath("$.content[0].refType").value("EXPENSE"))
			.andExpect(jsonPath("$.content[0].tripName").value("오사카"))
			.andExpect(jsonPath("$.content[0].isRead").value(false));
		perform(get("/api/notifications"), 1, null).andExpect(jsonPath("$.content.length()").value(0));
		perform(get("/api/notifications/unread-count"), 2, null).andExpect(jsonPath("$.count").value(1));

		String notificationId = read(perform(get("/api/notifications"), 2, null), "$.content[0].id");
		perform(patch("/api/notifications/" + notificationId + "/read"), 2, null).andExpect(status().isNoContent());
		perform(get("/api/notifications/unread-count"), 2, null).andExpect(jsonPath("$.count").value(0));
		// 다른 사람의 알림은 읽음 처리할 수 없다
		perform(patch("/api/notifications/" + notificationId + "/read"), 0, null).andExpect(status().isNotFound());
	}

	@Test
	void 알림_설정을_끈_사람에게는_보내지_않는다() throws Exception {
		perform(patch("/api/users/me/notification-settings"), 2, "{\"notifyExpense\":false}").andExpect(status().isOk());

		addExpense(1);

		perform(get("/api/notifications/unread-count"), 0, null).andExpect(jsonPath("$.count").value(1));
		perform(get("/api/notifications/unread-count"), 2, null).andExpect(jsonPath("$.count").value(0));
	}

	@Test
	void 일정_추가_수정_삭제와_정산_공유도_알림이_간다() throws Exception {
		String scheduleId = read(perform(post(tripUrl() + "/schedules"), 0, """
			{"day":"%s","startTime":"10:00","endTime":"11:00","title":"오사카성"}
			""".formatted(DAY)), "$.id");
		perform(patch(tripUrl() + "/schedules/" + scheduleId), 0, "{\"version\":0,\"title\":\"오사카성 천수각\"}");
		perform(delete(tripUrl() + "/schedules/" + scheduleId), 0, null);
		addExpense(1);
		perform(post(tripUrl() + "/settlement-shares"), 1, null).andExpect(status().isCreated());

		perform(get("/api/notifications"), 2, null)
			.andExpect(jsonPath("$.content.length()").value(5))
			.andExpect(jsonPath("$.content[0].type").value("SETTLEMENT_SHARED"))
			.andExpect(jsonPath("$.content[2].message").value("김방장님이 10.03 '오사카성 천수각' 일정을 삭제했어요"))
			.andExpect(jsonPath("$.content[2].refType").value("TRIP"))
			.andExpect(jsonPath("$.content[4].message").value("김방장님이 10.03 '오사카성' 일정을 추가했어요"));
	}

	@Test
	void 모두_읽음과_커서_페이지() throws Exception {
		for (int i = 0; i < 3; i++) {
			addExpense(1);
		}
		String cursor = read(perform(get("/api/notifications").param("size", "2"), 0, null)
			.andExpect(jsonPath("$.hasNext").value(true)), "$.nextCursor");
		perform(get("/api/notifications").param("size", "2").param("cursor", cursor), 0, null)
			.andExpect(jsonPath("$.content.length()").value(1))
			.andExpect(jsonPath("$.hasNext").value(false));

		perform(patch("/api/notifications/read-all"), 0, null).andExpect(status().isNoContent());
		perform(get("/api/notifications/unread-count"), 0, null).andExpect(jsonPath("$.count").value(0));
	}

	@Test
	void 여행을_지워도_알림은_남는다() throws Exception {
		perform(delete(tripUrl()), 0, null).andExpect(status().isNoContent());

		perform(get("/api/notifications"), 1, null)
			.andExpect(jsonPath("$.content[0].type").value("TRIP_DELETED"))
			.andExpect(jsonPath("$.content[0].message").value("김방장님이 '오사카' 여행을 삭제했어요"))
			.andExpect(jsonPath("$.content[0].refType").doesNotExist());
	}

	@Test
	void 준비_업무를_맡기면_담당자에게만_알린다() throws Exception {
		perform(post(tripUrl() + "/tasks"), 0, """
			{"scope":"TEAM","title":"환전하기","assigneeMemberId":"%s"}
			""".formatted(id(1))).andExpect(status().isCreated());

		perform(get("/api/notifications"), 1, null)
			.andExpect(jsonPath("$.content[0].type").value("TASK_ASSIGNED"))
			.andExpect(jsonPath("$.content[0].message").value("김방장님이 '환전하기' 준비를 맡겼어요"));
		perform(get("/api/notifications/unread-count"), 2, null).andExpect(jsonPath("$.count").value(0));
	}

	@Test
	void 기기_토큰은_마지막으로_로그인한_계정으로_옮겨지고_로그아웃하면_지워진다() throws Exception {
		perform(put("/api/device-tokens"), 0, "{\"fcmToken\":\"device-abc\"}").andExpect(status().isNoContent());
		perform(put("/api/device-tokens"), 1, "{\"fcmToken\":\"device-abc\"}").andExpect(status().isNoContent());

		assertThat(deviceTokenRepository.findByFcmToken("device-abc").orElseThrow().getUser().getId())
			.isEqualTo(users.get(1).getId());
		// 다른 계정이 지울 수는 없다
		perform(delete("/api/device-tokens"), 0, "{\"fcmToken\":\"device-abc\"}").andExpect(status().isNoContent());
		assertThat(deviceTokenRepository.findByFcmToken("device-abc")).isPresent();
		perform(delete("/api/device-tokens"), 1, "{\"fcmToken\":\"device-abc\"}").andExpect(status().isNoContent());
		assertThat(deviceTokenRepository.findByFcmToken("device-abc")).isEmpty();
	}

	@Test
	void 초대_코드로_참여하면_기존_멤버에게_알린다() throws Exception {
		perform(delete(tripUrl() + "/members/me"), 2, null).andExpect(status().isNoContent());
		notificationRepository.deleteAll();

		perform(post("/api/trips/join"), 2, "{\"inviteCode\":\"SUPP2345\"}").andExpect(status().isOk());

		perform(get("/api/notifications"), 0, null)
			.andExpect(jsonPath("$.content[0].type").value("MEMBER_JOINED"))
			.andExpect(jsonPath("$.content[0].message").value("박멤버님이 여행에 참여했어요"));
	}

	private void addExpense(int payer) throws Exception {
		perform(post(tripUrl() + "/expenses"), payer, """
			{"payerMemberId":"%s","title":"택시","category":"TRANSPORT","paidDate":"%s","rateMode":"KRW",
			 "amountKrw":12000,"splitMethod":"EQUAL","memberIds":["%s","%s"]}
			""".formatted(id(payer), DAY, id(0), id(payer))).andExpect(status().isCreated());
	}
}
