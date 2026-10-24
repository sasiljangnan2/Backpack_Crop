package com.backpackcorp.backpack.global.config;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.budget.domain.BudgetItem;
import com.backpackcorp.backpack.budget.domain.ExchangeRate;
import com.backpackcorp.backpack.expense.domain.Expense;
import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.domain.ExpenseItem;
import com.backpackcorp.backpack.expense.domain.ExpenseItemUser;
import com.backpackcorp.backpack.expense.domain.RateMode;
import com.backpackcorp.backpack.expense.domain.SplitMethod;
import com.backpackcorp.backpack.notification.domain.Notification;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.poll.domain.Poll;
import com.backpackcorp.backpack.poll.domain.PollOption;
import com.backpackcorp.backpack.poll.domain.PollVote;
import com.backpackcorp.backpack.schedule.domain.Schedule;
import com.backpackcorp.backpack.settlement.domain.SettlementShare;
import com.backpackcorp.backpack.settlement.domain.SettlementTransfer;
import com.backpackcorp.backpack.task.domain.Task;
import com.backpackcorp.backpack.task.domain.TaskScope;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.user.domain.Role;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;

import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

// 로컬 개발용 더미 데이터. dev 프로필에서만, 회원이 한 명도 없을 때 한 번 넣는다.
// 다시 넣으려면 DB를 비운다: docker compose down -v && docker compose up -d
//
// 들어가는 것: 회원 3명(방장·멤버·관리자), 진행 중인 오사카 여행 1개와 게스트 1명,
// 그 여행의 준비 업무·일정·투표·예산·지출·정산·알림
@Slf4j
@Component
@Profile("dev")
@RequiredArgsConstructor
public class DummyDataInitializer implements ApplicationRunner {

	// 세 계정 공통 비밀번호
	static final String PASSWORD = "backpack1234";

	private final UserRepository userRepository;
	private final PasswordEncoder passwordEncoder;
	private final EntityManager em;

	@Override
	@Transactional
	public void run(ApplicationArguments args) {
		if (userRepository.count() > 0) {
			return;
		}
		User hostUser = user("host@backpack.dev", "김방장", Role.USER);
		User memberUser = user("member@backpack.dev", "이멤버", Role.USER);
		user("admin@backpack.dev", "관리자", Role.ADMIN);

		// 어제 출발해 모레 돌아오는 여행
		LocalDate firstDay = LocalDate.now().minusDays(1);
		Trip trip = save(Trip.builder().name("오사카 먹방 여행").destination("일본 오사카")
			.startDate(firstDay).endDate(firstDay.plusDays(3)).currencyCode("JPY").inviteCode("OSAKA001").build());
		TripMember host = save(TripMember.builder().trip(trip).user(hostUser).role(TripMemberRole.HOST).build());
		TripMember member = save(TripMember.builder().trip(trip).user(memberUser).role(TripMemberRole.MEMBER)
			.prepaidRate(new BigDecimal("8.900000")).build());
		// 게스트 인증 방식이 정해지지 않아 토큰 해시는 자리만 채운다
		TripMember guest = save(TripMember.builder().trip(trip).role(TripMemberRole.GUEST).displayName("박게스트")
			.guestTokenHash("0".repeat(64)).build());

		save(Task.builder().trip(trip).creator(host).assignee(member).scope(TaskScope.TEAM).title("환전하기").build());
		save(Task.builder().trip(trip).creator(host).scope(TaskScope.TEAM).title("포켓 와이파이 예약").build());
		save(Task.builder().trip(trip).creator(host).assignee(host).scope(TaskScope.PRIVATE).title("여권 챙기기").build());

		save(Schedule.builder().trip(trip).day(firstDay).startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(12, 0))
			.title("오사카성").placeText("오사카성 공원").memo("천수각 입장권은 현장 구매").createdBy(host).build());
		save(Schedule.builder().trip(trip).day(firstDay).startTime(LocalTime.of(18, 0)).endTime(LocalTime.of(20, 0))
			.title("도톤보리 저녁").placeText("도톤보리").createdBy(member).build());
		save(Schedule.builder().trip(trip).day(firstDay.plusDays(1)).startTime(LocalTime.of(9, 30))
			.endTime(LocalTime.of(17, 0)).title("유니버설 스튜디오").createdBy(host).build());

		Poll poll = save(Poll.builder().trip(trip).creator(host).title("둘째 날 저녁 어디서 먹을까요?")
			.slotDate(firstDay.plusDays(1)).slotStart(LocalTime.of(18, 30)).slotEnd(LocalTime.of(20, 0)).build());
		PollOption ramen = save(PollOption.builder().poll(poll).label("이치란 라멘").memo("도보 5분").sortOrder(1).build());
		PollOption sushi = save(PollOption.builder().poll(poll).label("회전 초밥").memo("대기 30분").sortOrder(2).build());
		save(PollOption.builder().poll(poll).label("오코노미야키").sortOrder(3).build());
		save(PollVote.builder().poll(poll).option(ramen).member(host).build());
		save(PollVote.builder().poll(poll).option(ramen).member(member).build());
		save(PollVote.builder().poll(poll).option(sushi).member(guest).build());

		BigDecimal rate = new BigDecimal("9.050000");
		save(ExchangeRate.builder().currencyCode("JPY").rateDate(firstDay).rateToKrw(rate).build());
		save(BudgetItem.builder().trip(trip).category(ExpenseCategory.FOOD).name("식비")
			.amount(new BigDecimal("30000.00")).currencyCode("JPY").build());
		save(BudgetItem.builder().trip(trip).category(ExpenseCategory.LODGING).name("숙소")
			.amount(new BigDecimal("400000.00")).currencyCode("KRW").build());

		// 방장이 엔화로 결제 (3,000엔 × 9.05 = 27,150원), 셋이 똑같이 나눔
		Expense ramenBill = save(Expense.builder().trip(trip).payer(host).creator(host).title("이치란 라멘")
			.category(ExpenseCategory.FOOD).paidDate(firstDay).amountLocal(new BigDecimal("3000.00"))
			.rateMode(RateMode.API).appliedRate(rate).rateDate(firstDay).amountKrw(new BigDecimal("27150"))
			.splitMethod(SplitMethod.EQUAL).build());
		ExpenseItem ramenItem = save(ExpenseItem.builder().expense(ramenBill).name("총액")
			.amountLocal(new BigDecimal("3000.00")).amountKrw(new BigDecimal("27150")).sortOrder(1).build());
		share(ramenItem, host, "9050");
		share(ramenItem, member, "9050");
		share(ramenItem, guest, "9050");

		// 멤버가 원화로 직접 입력, 방장과 둘이 나눔
		Expense taxi = save(Expense.builder().trip(trip).payer(member).creator(member).title("공항 택시")
			.category(ExpenseCategory.TRANSPORT).paidDate(firstDay).rateMode(RateMode.KRW)
			.amountKrw(new BigDecimal("12000")).splitMethod(SplitMethod.EQUAL).build());
		ExpenseItem taxiItem = save(ExpenseItem.builder().expense(taxi).name("총액")
			.amountKrw(new BigDecimal("12000")).sortOrder(1).build());
		share(taxiItem, host, "6000");
		share(taxiItem, member, "6000");

		// 위 두 지출을 정산한 결과: 멤버 → 방장 3,050원, 게스트 → 방장 9,050원
		SettlementShare settlement = save(SettlementShare.builder().trip(trip).sharedBy(host).build());
		save(SettlementTransfer.builder().share(settlement).fromMember(member).toMember(host)
			.amountKrw(new BigDecimal("3050")).build());
		save(SettlementTransfer.builder().share(settlement).fromMember(guest).toMember(host)
			.amountKrw(new BigDecimal("9050")).build());

		save(Notification.builder().user(memberUser).tripId(trip.getId()).tripName(trip.getName())
			.type(NotificationType.EXPENSE_ADDED).message("김방장님이 지출 '이치란 라멘'을 추가했어요")
			.refType(NotificationRefType.EXPENSE).refId(ramenBill.getId()).build());
		save(Notification.builder().member(guest).tripId(trip.getId()).tripName(trip.getName())
			.type(NotificationType.SETTLEMENT_SHARED).message("김방장님이 정산 내역을 공유했어요")
			.refType(NotificationRefType.SETTLEMENT_SHARE).refId(settlement.getId()).build());

		log.info("더미 데이터를 넣었습니다. 계정: host@backpack.dev, member@backpack.dev, admin@backpack.dev");
	}

	private User user(String email, String name, Role role) {
		return save(User.builder().email(email).passwordHash(passwordEncoder.encode(PASSWORD)).name(name).role(role)
			.build());
	}

	private void share(ExpenseItem item, TripMember member, String shareKrw) {
		save(ExpenseItemUser.builder().item(item).member(member).shareKrw(new BigDecimal(shareKrw)).build());
	}

	private <T> T save(T entity) {
		em.persist(entity);
		return entity;
	}
}
