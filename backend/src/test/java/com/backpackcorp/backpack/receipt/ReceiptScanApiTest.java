package com.backpackcorp.backpack.receipt;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.time.LocalDate;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.replan.service.GeminiClient;
import com.backpackcorp.backpack.support.ApiTestSupport;
import com.backpackcorp.backpack.trip.domain.Trip;

// 영수증 읽기 (BP-EX-002): 사진 → Gemini → 다듬은 결과. Gemini는 가짜로 바꾼다
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ReceiptScanApiTest extends ApiTestSupport {

	// 일본 편의점 영수증 (외세: 항목 합계 2,799 + 소비세 223 = 3,022)을 Gemini가 읽은 모양
	private static final String SEVEN_ELEVEN = """
		{"store":"セブン-イレブン Kiosk高松駅店","storeKo":"세븐일레븐 키오스크 다카마쓰역점",
		 "date":"2026-03-08","time":"20:40","currency":"JPY",
		 "items":[
		  {"name":"7P蒙古タンメン中本辛旨味噌","nameKo":"몽고탄멘 나카모토 매운 된장 컵라면","qty":3,"unitPrice":240,"amount":720},
		  {"name":"チキン南蛮","nameKo":"치킨 난반","qty":1,"unitPrice":298,"amount":298},
		  {"name":"ねぎ塩豚カルビ弁当","nameKo":"파소금 돼지갈비 도시락","qty":1,"amount":520},
		  {"name":"値引","nameKo":"할인","qty":1,"amount":-20},
		  {"name":"ポッカ キレートレモン 155ml","nameKo":"포카 키레이토 레몬 155ml","qty":2,"unitPrice":175,"amount":350,"unclear":true},
		  {"name":"レジ袋","nameKo":"","qty":0,"amount":0},
		  {"name":"7P鉄板焼ハンバーグチーズイン","nameKo":"세븐프리미엄 치즈 함박스테이크","qty":1,"amount":298.4}
		 ],
		 "subtotal":2799,"tax":223,"taxIncluded":false,"total":3022}
		""";

	@MockitoBean
	private GeminiClient gemini;

	@BeforeEach
	void setUp() {
		setUpTrip(LocalDate.of(2026, 3, 7), LocalDate.of(2026, 3, 10), "JPY", "김방장", "이멤버");
		when(gemini.enabled()).thenReturn(true);
	}

	@Test
	void 영수증_사진을_읽어_항목_수량_금액과_한국어_번역을_준다() throws Exception {
		when(gemini.generateJson(anyString(), anyList(), anyMap(), anyDouble())).thenReturn(SEVEN_ELEVEN);

		scan(1, png())
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.store").value("セブン-イレブン Kiosk高松駅店"))
			.andExpect(jsonPath("$.storeKo").value("세븐일레븐 키오스크 다카마쓰역점"))
			.andExpect(jsonPath("$.date").value("2026-03-08"))
			.andExpect(jsonPath("$.time").value("20:40"))
			.andExpect(jsonPath("$.currency").value("JPY"))
			.andExpect(jsonPath("$.total").value(3022))
			.andExpect(jsonPath("$.tax").value(223))
			.andExpect(jsonPath("$.taxIncluded").value(false))
			// 0원 줄은 빼고, 할인(-20)은 바로 위 도시락에서 뺀다
			.andExpect(jsonPath("$.items.length()").value(5))
			.andExpect(jsonPath("$.items[0].qty").value(3))
			.andExpect(jsonPath("$.items[0].unitPrice").value(240))
			.andExpect(jsonPath("$.items[0].amount").value(720))
			.andExpect(jsonPath("$.items[0].nameKo").value("몽고탄멘 나카모토 매운 된장 컵라면"))
			.andExpect(jsonPath("$.items[2].name").value("ねぎ塩豚カルビ弁当"))
			.andExpect(jsonPath("$.items[2].amount").value(500))
			.andExpect(jsonPath("$.items[3].unclear").value(true))
			// 엔은 소수점이 없다
			.andExpect(jsonPath("$.items[4].amount").value(298));
	}

	@Test
	void 한국어_영수증은_번역을_붙이지_않는다() throws Exception {
		when(gemini.generateJson(anyString(), anyList(), anyMap(), anyDouble())).thenReturn("""
			{"store":"스타벅스 강남점","storeKo":"스타벅스 강남점","currency":"KRW","date":"","time":"9:15",
			 "items":[{"name":"아메리카노","nameKo":"아메리카노","qty":2,"amount":9000},
			          {"name":"Cheese Cake","nameKo":"치즈케이크","qty":1,"amount":6500}],
			 "tax":0,"taxIncluded":true,"total":15500}
			""");

		scan(0, png())
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.storeKo").doesNotExist())
			.andExpect(jsonPath("$.date").doesNotExist())
			.andExpect(jsonPath("$.time").value("09:15"))
			.andExpect(jsonPath("$.currency").value("KRW"))
			.andExpect(jsonPath("$.items[0].nameKo").doesNotExist())
			// 영어는 번역한다
			.andExpect(jsonPath("$.items[1].nameKo").value("치즈케이크"))
			.andExpect(jsonPath("$.items[0].unitPrice").value(4500));
	}

	@Test
	void 총액을_못_읽으면_422() throws Exception {
		when(gemini.generateJson(anyString(), anyList(), anyMap(), anyDouble())).thenReturn("""
			{"store":"","storeKo":"","currency":"JPY","items":[],"tax":0,"taxIncluded":true,"total":0}
			""");

		scan(0, png())
			.andExpect(status().is(422))
			.andExpect(jsonPath("$.code").value("RECEIPT_UNREADABLE"));
	}

	@Test
	void Gemini가_답하지_않거나_이상하게_답하면_503() throws Exception {
		when(gemini.generateJson(anyString(), anyList(), anyMap(), anyDouble()))
			.thenThrow(new IllegalStateException("Gemini가 25초 안에 답하지 않았어요"))
			.thenReturn("영수증이 아니에요");

		scan(0, png())
			.andExpect(status().isServiceUnavailable())
			.andExpect(jsonPath("$.code").value("RECEIPT_AI_FAILED"));
		scan(0, png())
			.andExpect(status().isServiceUnavailable())
			.andExpect(jsonPath("$.code").value("RECEIPT_AI_FAILED"));
	}

	@Test
	void 키가_없으면_503이고_앱이_기기_안_OCR을_쓴다() throws Exception {
		when(gemini.enabled()).thenReturn(false);

		scan(0, png())
			.andExpect(status().isServiceUnavailable())
			.andExpect(jsonPath("$.code").value("RECEIPT_AI_UNAVAILABLE"));
		verify(gemini, never()).generateJson(anyString(), anyList(), anyMap(), anyDouble());
	}

	@Test
	void 이미지가_아니면_400_멤버가_아니면_403() throws Exception {
		scan(0, "hello".getBytes())
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("INVALID_IMAGE"));

		Trip other = tripRepository.save(Trip.builder().name("도쿄").destination("일본 도쿄")
			.startDate(LocalDate.of(2026, 3, 7)).endDate(LocalDate.of(2026, 3, 9)).currencyCode("JPY")
			.timeZone("Asia/Tokyo").inviteCode("OTHR2345").build());
		scan("/api/trips/" + other.getId(), 0, png())
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("NOT_TRIP_MEMBER"));
		verify(gemini, never()).generateJson(anyString(), anyList(), any(), anyDouble());
	}

	private ResultActions scan(int member, byte[] image) throws Exception {
		return scan(tripUrl(), member, image);
	}

	// multipart 요청은 MockHttpServletRequestBuilder가 아니라서 perform을 쓰지 않고 토큰을 직접 붙인다
	private ResultActions scan(String tripUrl, int member, byte[] image) throws Exception {
		return mockMvc.perform(multipart(tripUrl + "/receipts/scan").file(file(image))
			.header(HttpHeaders.AUTHORIZATION, "Bearer " + tokens.get(member)));
	}

	private static MockMultipartFile file(byte[] image) {
		return new MockMultipartFile("image", "receipt.png", "image/png", image);
	}

	private static byte[] png() throws Exception {
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		ImageIO.write(new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB), "png", out);
		return out.toByteArray();
	}
}
