package com.backpackcorp.backpack;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.budget.domain.BudgetItem;
import com.backpackcorp.backpack.budget.domain.ExchangeRate;
import com.backpackcorp.backpack.budget.repository.BudgetItemRepository;
import com.backpackcorp.backpack.budget.repository.ExchangeRateRepository;
import com.backpackcorp.backpack.expense.domain.Expense;
import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.domain.ExpenseItem;
import com.backpackcorp.backpack.expense.domain.ExpenseItemUser;
import com.backpackcorp.backpack.expense.domain.ExpenseItemUserId;
import com.backpackcorp.backpack.expense.domain.RateMode;
import com.backpackcorp.backpack.expense.domain.SplitMethod;
import com.backpackcorp.backpack.expense.repository.ExpenseItemRepository;
import com.backpackcorp.backpack.expense.repository.ExpenseItemUserRepository;
import com.backpackcorp.backpack.expense.repository.ExpenseRepository;
import com.backpackcorp.backpack.notification.domain.DeviceToken;
import com.backpackcorp.backpack.notification.domain.Notification;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.repository.DeviceTokenRepository;
import com.backpackcorp.backpack.notification.repository.NotificationRepository;
import com.backpackcorp.backpack.poll.domain.Poll;
import com.backpackcorp.backpack.poll.domain.PollOption;
import com.backpackcorp.backpack.poll.domain.PollStatus;
import com.backpackcorp.backpack.poll.domain.PollVote;
import com.backpackcorp.backpack.poll.repository.PollOptionRepository;
import com.backpackcorp.backpack.poll.repository.PollRepository;
import com.backpackcorp.backpack.poll.repository.PollVoteRepository;
import com.backpackcorp.backpack.schedule.domain.ReservationStatus;
import com.backpackcorp.backpack.schedule.domain.Schedule;
import com.backpackcorp.backpack.schedule.repository.ScheduleRepository;
import com.backpackcorp.backpack.settlement.domain.SettlementShare;
import com.backpackcorp.backpack.settlement.domain.SettlementTransfer;
import com.backpackcorp.backpack.settlement.repository.SettlementShareRepository;
import com.backpackcorp.backpack.settlement.repository.SettlementTransferRepository;
import com.backpackcorp.backpack.task.domain.Task;
import com.backpackcorp.backpack.task.domain.TaskScope;
import com.backpackcorp.backpack.task.repository.TaskRepository;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.domain.TripMemberRole;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.repository.TripRepository;
import com.backpackcorp.backpack.user.domain.Role;
import com.backpackcorp.backpack.user.domain.User;
import com.backpackcorp.backpack.user.repository.UserRepository;

import jakarta.persistence.EntityManager;

// 모든 엔티티를 리포지토리로 한 번씩 저장하고 다시 읽어, 매핑과 기본값이 맞는지 확인한다
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class EntityMappingTest {

	@Autowired
	private EntityManager entityManager;
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private TripRepository tripRepository;
	@Autowired
	private TripMemberRepository tripMemberRepository;
	@Autowired
	private TaskRepository taskRepository;
	@Autowired
	private DeviceTokenRepository deviceTokenRepository;
	@Autowired
	private NotificationRepository notificationRepository;
	@Autowired
	private ScheduleRepository scheduleRepository;
	@Autowired
	private PollRepository pollRepository;
	@Autowired
	private PollOptionRepository pollOptionRepository;
	@Autowired
	private PollVoteRepository pollVoteRepository;
	@Autowired
	private ExchangeRateRepository exchangeRateRepository;
	@Autowired
	private BudgetItemRepository budgetItemRepository;
	@Autowired
	private ExpenseRepository expenseRepository;
	@Autowired
	private ExpenseItemRepository expenseItemRepository;
	@Autowired
	private ExpenseItemUserRepository expenseItemUserRepository;
	@Autowired
	private SettlementShareRepository settlementShareRepository;
	@Autowired
	private SettlementTransferRepository settlementTransferRepository;

	@Test
	void 모든_엔티티를_저장하고_다시_읽는다() {
		LocalDate day = LocalDate.of(2026, 1, 1);
		User user = userRepository.save(User.builder().email("a@b.c").passwordHash("{bcrypt}hash").name("홍길동").build());
		Trip trip = tripRepository.save(Trip.builder().name("오사카").destination("일본 오사카")
			.startDate(day).endDate(day.plusDays(2)).currencyCode("JPY").inviteCode("ABCD1234").build());
		TripMember host = tripMemberRepository.save(
			TripMember.builder().trip(trip).user(user).role(TripMemberRole.HOST).build());
		TripMember guest = tripMemberRepository.save(TripMember.builder().trip(trip).role(TripMemberRole.GUEST)
			.displayName("게스트").guestTokenHash("a".repeat(64)).prepaidRate(new BigDecimal("9.123456")).build());

		Task task = taskRepository.save(
			Task.builder().trip(trip).creator(host).assignee(guest).scope(TaskScope.TEAM).title("환전").build());
		DeviceToken deviceToken = deviceTokenRepository.save(DeviceToken.builder().user(user).fcmToken("fcm").build());
		Notification notification = notificationRepository.save(Notification.builder().member(guest)
			.tripId(trip.getId()).tripName(trip.getName()).type(NotificationType.EXPENSE_ADDED)
			.message("지출이 추가됐습니다").build());
		Schedule schedule = scheduleRepository.save(Schedule.builder().trip(trip).day(day)
			.startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(11, 0)).title("오사카성").createdBy(host).build());

		Poll poll = pollRepository.save(Poll.builder().trip(trip).creator(host).title("점심")
			.slotDate(day).slotStart(LocalTime.of(12, 0)).slotEnd(LocalTime.of(13, 0)).build());
		PollOption option = pollOptionRepository.save(PollOption.builder().poll(poll).label("라멘").sortOrder(1).build());
		PollVote vote = pollVoteRepository.save(PollVote.builder().poll(poll).option(option).member(guest).build());

		ExchangeRate rate = exchangeRateRepository.save(
			ExchangeRate.builder().currencyCode("JPY").rateDate(day).rateToKrw(new BigDecimal("9.050000")).build());
		BudgetItem budgetItem = budgetItemRepository.save(BudgetItem.builder().trip(trip)
			.category(ExpenseCategory.FOOD).name("식비")
			.amount(new BigDecimal("30000.00")).currencyCode("JPY").build());

		Expense expense = expenseRepository.save(Expense.builder().trip(trip).payer(host).creator(guest).title("라멘집")
			.category(ExpenseCategory.FOOD).paidDate(day).rateMode(RateMode.KRW).amountKrw(new BigDecimal("20000"))
			.splitMethod(SplitMethod.EQUAL).build());
		ExpenseItem item = expenseItemRepository.save(
			ExpenseItem.builder().expense(expense).name("총액").amountKrw(new BigDecimal("20000")).sortOrder(1).build());
		expenseItemUserRepository.save(
			ExpenseItemUser.builder().item(item).member(guest).shareKrw(new BigDecimal("10000")).build());

		SettlementShare share = settlementShareRepository.save(
			SettlementShare.builder().trip(trip).sharedBy(host).build());
		SettlementTransfer transfer = settlementTransferRepository.save(SettlementTransfer.builder().share(share)
			.fromMember(guest).toMember(host).amountKrw(new BigDecimal("10000")).build());

		entityManager.flush();
		entityManager.clear();

		// 기본값
		User foundUser = userRepository.findById(user.getId()).orElseThrow();
		assertThat(foundUser.getRole()).isEqualTo(Role.USER);
		assertThat(foundUser.isNotifySchedule()).isTrue();
		assertThat(taskRepository.findById(task.getId()).orElseThrow().isDone()).isFalse();
		assertThat(notificationRepository.findById(notification.getId()).orElseThrow().isRead()).isFalse();
		Schedule foundSchedule = scheduleRepository.findById(schedule.getId()).orElseThrow();
		assertThat(foundSchedule.getReservationStatus()).isEqualTo(ReservationStatus.NONE);
		assertThat(foundSchedule.isLocked()).isFalse();
		assertThat(pollRepository.findById(poll.getId()).orElseThrow().getStatus()).isEqualTo(PollStatus.OPEN);

		// 자동으로 채워지는 시각
		TripMember foundGuest = tripMemberRepository.findById(guest.getId()).orElseThrow();
		assertThat(foundGuest.getJoinedAt()).isNotNull();
		assertThat(foundGuest.getUser()).isNull();
		assertThat(foundGuest.getPrepaidRate()).isEqualByComparingTo("9.123456");
		assertThat(deviceTokenRepository.findById(deviceToken.getId()).orElseThrow().getUpdatedAt()).isNotNull();
		assertThat(pollVoteRepository.findById(vote.getId()).orElseThrow().getUpdatedAt()).isNotNull();
		assertThat(exchangeRateRepository.findById(rate.getId()).orElseThrow().getFetchedAt()).isNotNull();

		// 연관 관계와 복합 키
		assertThat(tripMemberRepository.findById(host.getId()).orElseThrow().getTrip().getInviteCode())
			.isEqualTo("ABCD1234");
		assertThat(budgetItemRepository.findById(budgetItem.getId()).orElseThrow().getCurrencyCode()).isEqualTo("JPY");
		ExpenseItemUser foundShare = expenseItemUserRepository
			.findById(new ExpenseItemUserId(item.getId(), guest.getId())).orElseThrow();
		assertThat(foundShare.getShareKrw()).isEqualByComparingTo("10000");
		assertThat(foundShare.getItem().getExpense().getPayer().getId()).isEqualTo(host.getId());
		assertThat(settlementTransferRepository.findById(transfer.getId()).orElseThrow().getToMember().getId())
			.isEqualTo(host.getId());
		assertThat(pollOptionRepository.findById(option.getId()).orElseThrow().getSortOrder()).isEqualTo(1);
	}
}
