package com.backpackcorp.backpack.support;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
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
import com.jayway.jsonpath.JsonPath;

// API 테스트 공통: 여행 하나와 멤버(0번이 방장)를 만들고 멤버별 액세스 토큰으로 요청한다.
// 하위 클래스에 @SpringBootTest · @ActiveProfiles("test") · @Transactional을 붙인다
public abstract class ApiTestSupport {

	@Autowired
	protected WebApplicationContext context;
	@Autowired
	protected TokenService tokenService;
	@Autowired
	protected UserRepository userRepository;
	@Autowired
	protected TripRepository tripRepository;
	@Autowired
	protected TripMemberRepository tripMemberRepository;

	protected MockMvc mockMvc;
	protected Trip trip;
	protected final List<TripMember> members = new ArrayList<>();
	protected final List<User> users = new ArrayList<>();
	protected final List<String> tokens = new ArrayList<>();

	protected void setUpTrip(LocalDate start, LocalDate end, String currency, String... names) {
		mockMvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
		trip = tripRepository.save(Trip.builder().name("오사카").destination("일본 오사카").startDate(start).endDate(end)
			.currencyCode(currency).timeZone("Asia/Tokyo").inviteCode("SUPP2345").build());
		for (int i = 0; i < names.length; i++) {
			User user = userRepository.save(User.builder().email("s" + i + "@b.c").passwordHash("{noop}x")
				.name(names[i]).build());
			users.add(user);
			members.add(tripMemberRepository.save(TripMember.builder().trip(trip).user(user)
				.role(i == 0 ? TripMemberRole.HOST : TripMemberRole.MEMBER).build()));
			tokens.add(tokenService.createAccessToken(user.getId(), Role.USER));
		}
	}

	protected ResultActions perform(MockHttpServletRequestBuilder request, int member, String body) throws Exception {
		request.header(HttpHeaders.AUTHORIZATION, "Bearer " + tokens.get(member));
		if (body != null) {
			request.contentType(MediaType.APPLICATION_JSON).content(body);
		}
		return mockMvc.perform(request);
	}

	protected String tripUrl() {
		return "/api/trips/" + trip.getId();
	}

	protected String id(int member) {
		return members.get(member).getId().toString();
	}

	protected static String read(ResultActions result, String path) throws Exception {
		return JsonPath.read(result.andReturn().getResponse().getContentAsString(), path).toString();
	}
}
