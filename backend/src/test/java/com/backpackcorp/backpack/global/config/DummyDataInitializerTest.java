package com.backpackcorp.backpack.global.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;

import com.backpackcorp.backpack.expense.repository.ExpenseItemUserRepository;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;

// dev 프로필을 켜면 기동할 때 더미 데이터가 들어간다. 다른 테스트와 섞이지 않게 DB를 따로 쓴다
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:dummy;MODE=MySQL")
@ActiveProfiles({"dev", "test"})
class DummyDataInitializerTest {

	@Autowired
	private DummyDataInitializer initializer;
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private TripMemberRepository tripMemberRepository;
	@Autowired
	private ExpenseItemUserRepository expenseItemUserRepository;
	@Autowired
	private PasswordEncoder passwordEncoder;

	@Test
	void 기동하면_더미_데이터가_들어가고_다시_실행해도_늘어나지_않는다() {
		initializer.run(new DefaultApplicationArguments());

		assertThat(userRepository.count()).isEqualTo(3);
		assertThat(tripMemberRepository.count()).isEqualTo(3);
		assertThat(expenseItemUserRepository.count()).isEqualTo(5);
		User anyUser = userRepository.findAll().getFirst();
		assertThat(passwordEncoder.matches(DummyDataInitializer.PASSWORD, anyUser.getPasswordHash())).isTrue();
	}
}
