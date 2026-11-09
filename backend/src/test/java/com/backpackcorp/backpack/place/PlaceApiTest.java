package com.backpackcorp.backpack.place;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.backpackcorp.backpack.global.security.TokenService;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.repository.TripRepository;
import com.backpackcorp.backpack.user.domain.Role;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;

// 테스트 트랜잭션 없이 실제 요청처럼 부른다 (트랜잭션 밖에서 여행을 읽다 실패한 적이 있다).
// 지도 서버는 꺼져 있으므로 검색 결과는 빈 목록이다
@SpringBootTest
@ActiveProfiles("test")
class PlaceApiTest {

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

	private MockMvc mockMvc;
	private User user;
	private Trip trip;
	private TripMember member;
	private String token;

	@BeforeEach
	void setUp() {
		mockMvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
		user = userRepository.save(User.builder().email("place@b.c").passwordHash("{noop}x").name("지도").build());
		trip = tripRepository.save(Trip.builder().name("오사카").destination("일본 오사카")
			.startDate(LocalDate.of(2026, 10, 1)).endDate(LocalDate.of(2026, 10, 4)).currencyCode("JPY")
			.timeZone("Asia/Tokyo").inviteCode("PLAC2345").build());
		member = tripMemberRepository.save(TripMember.builder().trip(trip).user(user).role(TripMemberRole.HOST).build());
		token = tokenService.createAccessToken(user.getId(), Role.USER);
	}

	@AfterEach
	void tearDown() {
		tripMemberRepository.delete(member);
		tripRepository.delete(trip);
		userRepository.delete(user);
	}

	@Test
	void 여행지_근처로_검색한다() throws Exception {
		mockMvc.perform(get("/api/places/search").param("q", "黒門市場").param("tripId", trip.getId().toString())
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.length()").value(0));
	}

	@Test
	void 검색어가_없거나_좌표가_잘못되면_400이다() throws Exception {
		mockMvc.perform(get("/api/places/search").param("q", " ")
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
			.andExpect(status().isBadRequest());
		mockMvc.perform(get("/api/places/reverse").param("lat", "91").param("lng", "0")
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
			.andExpect(status().isBadRequest());
		mockMvc.perform(get("/api/places/reverse").param("lat", "34.6").param("lng", "135.5")
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
			.andExpect(status().isNoContent());
	}
}
