package com.backpackcorp.backpack.expense.service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Slice;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.budget.dto.AppliedRate;
import com.backpackcorp.backpack.budget.dto.ExchangeRateResponse;
import com.backpackcorp.backpack.budget.service.ExchangeRateService;
import com.backpackcorp.backpack.expense.domain.Expense;
import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.domain.ExpenseItem;
import com.backpackcorp.backpack.expense.domain.ExpenseItemUser;
import com.backpackcorp.backpack.expense.domain.RateMode;
import com.backpackcorp.backpack.expense.domain.SplitMethod;
import com.backpackcorp.backpack.expense.dto.ExpenseAmountDto;
import com.backpackcorp.backpack.expense.dto.ExpenseBundle;
import com.backpackcorp.backpack.expense.dto.ExpenseBundle.ItemBundle;
import com.backpackcorp.backpack.expense.dto.ExpenseDetailResponse;
import com.backpackcorp.backpack.expense.dto.ExpenseItemRequest;
import com.backpackcorp.backpack.expense.dto.ExpenseListItemResponse;
import com.backpackcorp.backpack.expense.dto.ExpenseListResponse;
import com.backpackcorp.backpack.expense.dto.ExpenseRequest;
import com.backpackcorp.backpack.expense.dto.ExpenseShareRequest;
import com.backpackcorp.backpack.expense.dto.ExpenseTotalsDto;
import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.expense.repository.ExpenseItemRepository;
import com.backpackcorp.backpack.expense.repository.ExpenseItemUserRepository;
import com.backpackcorp.backpack.expense.repository.ExpenseRepository;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.dto.TripNotificationEvent;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.RequiredArgsConstructor;

// 지출 목록 · 등록 · 미리보기.
// 금액 계산 규칙은 ExpenseSplitCalculator에 있고, 여기서는 요청 검증과 저장만 한다.
// 등록과 미리보기는 같은 계산(plan)을 거치므로 미리보기 결과가 곧 저장될 값이다
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ExpenseService {

	private static final String SINGLE_ITEM_NAME = "총액";
	// 첫 페이지 조회 때 커서 ID 자리에 넣는 값. cursorDate가 null이면 쓰이지 않는다
	private static final UUID NO_CURSOR_ID = new UUID(0, 0);

	private final TripMemberGuard tripMemberGuard;
	private final TripMemberRepository tripMemberRepository;
	private final ExpenseRepository expenseRepository;
	private final ExpenseItemRepository expenseItemRepository;
	private final ExpenseItemUserRepository expenseItemUserRepository;
	private final ExchangeRateService exchangeRateService;
	private final ApplicationEventPublisher eventPublisher;

	public ExpenseListResponse getExpenses(UUID tripId, UUID userId, LocalDate date, ExpenseCategory category,
		String cursor, int size) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		Cursor parsed = Cursor.parse(cursor);

		Slice<Expense> slice = expenseRepository.findPage(tripId, date, category, parsed.paidDate(), parsed.id(),
			PageRequest.of(0, size));
		List<UUID> ids = slice.getContent().stream().map(Expense::getId).toList();
		Map<UUID, Long> myShares = ids.isEmpty() ? Map.of() : expenseItemUserRepository
			.sumShareByExpense(me.getId(), ids).stream()
			.collect(Collectors.toMap(ExpenseAmountDto::expenseId, ExpenseAmountDto::amount));

		List<ExpenseListItemResponse> content = slice.getContent().stream()
			.map(expense -> ExpenseListItemResponse.of(expense, me.getId(), myShares.getOrDefault(expense.getId(), 0L)))
			.toList();
		String nextCursor = slice.hasNext() ? Cursor.of(content.getLast()) : null;

		ExpenseTotalsDto totals = expenseRepository.sumByTrip(tripId, date, category);
		ExchangeRateResponse todayRate = ExchangeRateService.KRW.equals(trip.getCurrencyCode())
			? null
			: exchangeRateService.findTodayRate(trip.getCurrencyCode()).orElse(null);
		ExpenseListResponse.Summary summary = new ExpenseListResponse.Summary(totals.countValue(),
			totals.totalValue(), trip.getCurrencyCode(), todayRate);
		return new ExpenseListResponse(content, nextCursor, slice.hasNext(), summary);
	}

	// 저장하지 않고 계산 결과만 돌려준다 (지출 입력 ① 원화 환산, ② 분담 화면)
	public ExpenseDetailResponse previewExpense(UUID tripId, UUID userId, ExpenseRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Plan plan = plan(me, request, null);
		List<ItemBundle> items = plan.items().stream()
			.map(item -> new ItemBundle(item.item(), toShares(item.item(), item.shares())))
			.toList();
		return ExpenseDetailResponse.from(new ExpenseBundle(plan.expense(), items));
	}

	@Transactional
	public ExpenseDetailResponse createExpense(UUID tripId, UUID userId, ExpenseRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Plan plan = plan(me, request, null);
		expenseRepository.save(plan.expense());
		ExpenseDetailResponse response = ExpenseDetailResponse.from(saveItems(plan));
		String message = MemberRef.nameOf(me) + "님이 '" + response.title() + "' 지출을 추가했어요 · ₩"
			+ String.format("%,d", response.amountKrw());
		eventPublisher.publishEvent(TripNotificationEvent.of(me.getTrip(), me, NotificationType.EXPENSE_ADDED, message,
			NotificationRefType.EXPENSE, response.id()));
		return response;
	}

	// BP-EX-005 지출 상세
	public ExpenseDetailResponse getExpense(UUID tripId, UUID expenseId, UUID userId) {
		tripMemberGuard.requireMember(tripId, userId);
		return ExpenseDetailResponse.from(loadBundle(findExpense(tripId, expenseId)));
	}

	// 전체 교체. 항목·분담을 지우고 다시 만든다. 결제자 · 작성자 · 방장만 할 수 있다
	@Transactional
	public ExpenseDetailResponse updateExpense(UUID tripId, UUID expenseId, UUID userId, ExpenseRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Expense expense = findExpense(tripId, expenseId);
		requireEditor(expense, me);
		if (request.version() == null) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "version", "version이 필요해요. 지출을 다시 불러와 주세요.");
		}
		if (expense.getVersion() != request.version()) {
			throw BaseException.of(ErrorCode.VERSION_CONFLICT, "version", String.valueOf(expense.getVersion()));
		}
		expenseItemUserRepository.deleteByExpenseId(expense.getId());
		expenseItemRepository.deleteByExpenseId(expense.getId());
		// 일괄 삭제가 영속성 컨텍스트를 비우므로 지출을 다시 읽는다
		Expense reloaded = findExpense(tripId, expenseId);
		Plan plan = plan(reloaded.getCreator(), request, reloaded);
		ExpenseBundle bundle = saveItems(plan);
		// 응답의 version이 이번 수정을 반영하도록 먼저 반영한다
		expenseRepository.flush();
		return ExpenseDetailResponse.from(bundle);
	}

	@Transactional
	public void deleteExpense(UUID tripId, UUID expenseId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Expense expense = findExpense(tripId, expenseId);
		requireEditor(expense, me);
		expenseItemUserRepository.deleteByExpenseId(expense.getId());
		expenseItemRepository.deleteByExpenseId(expense.getId());
		expenseRepository.deleteById(expense.getId());
	}

	private ExpenseBundle saveItems(Plan plan) {
		List<ItemBundle> items = new ArrayList<>();
		for (ItemPlan itemPlan : plan.items()) {
			ExpenseItem item = expenseItemRepository.save(itemPlan.item());
			// 분담 행은 항목 ID가 있어야 만들 수 있으므로 항목을 저장한 뒤에 만든다
			List<ExpenseItemUser> shares = expenseItemUserRepository.saveAll(toShares(item, itemPlan.shares()));
			items.add(new ItemBundle(item, shares));
		}
		return new ExpenseBundle(plan.expense(), items);
	}

	private ExpenseBundle loadBundle(Expense expense) {
		List<ExpenseItem> items = expenseItemRepository.findByExpenseIdOrderBySortOrder(expense.getId());
		Map<UUID, List<ExpenseItemUser>> sharesByItem = items.isEmpty() ? Map.of() : expenseItemUserRepository
			.findWithMemberByItemIds(items.stream().map(ExpenseItem::getId).toList()).stream()
			.collect(Collectors.groupingBy(share -> share.getItem().getId()));
		return new ExpenseBundle(expense, items.stream()
			.map(item -> new ItemBundle(item, sharesByItem.getOrDefault(item.getId(), List.of())))
			.toList());
	}

	private Expense findExpense(UUID tripId, UUID expenseId) {
		return expenseRepository.findDetail(expenseId, tripId)
			.orElseThrow(() -> new BaseException(ErrorCode.EXPENSE_NOT_FOUND));
	}

	private static void requireEditor(Expense expense, TripMember me) {
		boolean editor = me.isHost() || expense.getPayer().getId().equals(me.getId())
			|| expense.getCreator().getId().equals(me.getId());
		if (!editor) {
			throw new BaseException(ErrorCode.NOT_EXPENSE_EDITOR);
		}
	}

	// ---- 계산 ----

	// existing이 있으면(수정) 그 엔티티에 새 값을 덮어쓰고, 없으면(등록·미리보기) 새 엔티티를 만든다
	private Plan plan(TripMember creator, ExpenseRequest request, Expense existing) {
		Trip trip = creator.getTrip();
		Map<UUID, TripMember> members = tripMemberRepository.findAllWithUserByTripId(trip.getId()).stream()
			.filter(member -> member.getLeftAt() == null)
			.collect(Collectors.toMap(TripMember::getId, Function.identity(), (a, b) -> a, LinkedHashMap::new));
		TripMember payer = members.get(request.payerMemberId());
		if (payer == null) {
			throw invalid("payerMemberId", "이 여행의 멤버만 결제자로 선택할 수 있어요.");
		}

		Money money = resolveMoney(trip, payer, request, existing);
		List<ExpenseItemRequest> itemRequests = normalizeItems(request);
		List<Long> itemAmountsKrw = allocateItems(request, money, itemRequests);

		Expense planned = Expense.builder().trip(trip).payer(payer).creator(creator).title(request.title().trim())
			.category(request.category()).paidDate(request.paidDate()).amountLocal(money.amountLocal())
			.rateMode(request.rateMode()).appliedRate(money.rate()).rateDate(money.rateDate())
			.amountKrw(BigDecimal.valueOf(money.amountKrw())).splitMethod(request.splitMethod()).build();
		Expense expense = planned;
		if (existing != null) {
			existing.replaceWith(planned);
			expense = existing;
		}

		List<ItemPlan> items = new ArrayList<>();
		long shareSum = 0;
		for (int i = 0; i < itemRequests.size(); i++) {
			ExpenseItemRequest itemRequest = itemRequests.get(i);
			long itemKrw = itemAmountsKrw.get(i);
			BigDecimal itemLocal = request.splitMethod() == SplitMethod.ITEM
				? itemRequest.amountLocal()
				: money.amountLocal();
			ExpenseItem item = ExpenseItem.builder().expense(expense).name(itemName(itemRequest, i))
				.amountLocal(request.rateMode() == RateMode.KRW ? null : itemLocal)
				.amountKrw(BigDecimal.valueOf(itemKrw)).sortOrder(i + 1).build();
			Map<TripMember, Long> shares = splitItem(request.splitMethod(), "items[" + i + "]", itemRequest, itemKrw,
				payer, members);
			shareSum += shares.values().stream().mapToLong(Long::longValue).sum();
			items.add(new ItemPlan(item, shares));
		}
		// 계산 규칙상 항상 같다. 다르면 코드 오류이므로 저장하지 않는다
		if (shareSum != money.amountKrw()) {
			throw new IllegalStateException("분담 합계가 총액과 다릅니다: " + shareSum + " != " + money.amountKrw());
		}
		return new Plan(expense, items);
	}

	private Money resolveMoney(Trip trip, TripMember payer, ExpenseRequest request, Expense existing) {
		if (request.rateMode() == RateMode.KRW) {
			if (request.amountKrw() == null) {
				throw invalid("amountKrw", "원화 금액을 입력해 주세요.");
			}
			if (request.amountLocal() != null || request.manualRate() != null) {
				throw invalid("rateMode", "원화로 입력할 때는 외화 금액과 환율을 보내지 않아요.");
			}
			return new Money(null, null, null, request.amountKrw());
		}

		String currencyCode = trip.getCurrencyCode();
		if (ExchangeRateService.KRW.equals(currencyCode)) {
			throw invalid("rateMode", "원화 여행에서는 원화(KRW)로만 입력할 수 있어요.");
		}
		if (request.amountLocal() == null) {
			throw invalid("amountLocal", "금액을 입력해 주세요.");
		}
		if (request.amountKrw() != null) {
			throw invalid("amountKrw", "외화로 입력할 때는 원화 금액을 서버가 계산해요.");
		}
		if (request.rateMode() != RateMode.MANUAL && request.manualRate() != null) {
			throw invalid("manualRate", "직접 입력(MANUAL)일 때만 환율을 보내요.");
		}

		BigDecimal rate;
		LocalDate rateDate = null;
		switch (request.rateMode()) {
			case API -> {
				if (existing != null && existing.getRateMode() == RateMode.API
					&& existing.getPaidDate().equals(request.paidDate())) {
					// 결제일이 그대로면 등록 때 적용한 환율을 유지한다 (그 사이 환율 값이 보정됐어도 금액이 바뀌지 않게)
					rate = existing.getAppliedRate();
					rateDate = existing.getRateDate();
				} else {
					AppliedRate applied = exchangeRateService.findRate(currencyCode, request.paidDate());
					rate = applied.rateToKrw();
					rateDate = applied.rateDate();
				}
			}
			case PREPAID -> {
				rate = payer.getPrepaidRate();
				if (rate == null) {
					throw BaseException.of(ErrorCode.PREPAID_RATE_NOT_SET, "payerMemberId",
						MemberRef.nameOf(payer) + "님의 선불 환율이 없어요.");
				}
			}
			case MANUAL -> {
				rate = request.manualRate();
				if (rate == null) {
					throw invalid("manualRate", "적용할 환율을 입력해 주세요.");
				}
			}
			default -> throw new IllegalStateException("처리하지 않은 환율 방식: " + request.rateMode());
		}
		BigDecimal amountLocal = request.amountLocal().setScale(2);
		long amountKrw = ExpenseSplitCalculator.toKrw(amountLocal, rate);
		if (amountKrw <= 0) {
			throw invalid("amountLocal", "원화로 바꾸면 0원이에요. 금액을 확인해 주세요.");
		}
		return new Money(amountLocal, rate.setScale(6), rateDate, amountKrw);
	}

	// 균등 분담은 items 없이 memberIds만 보내도 된다. 그 경우 총액 항목 1개로 바꾼다
	private static List<ExpenseItemRequest> normalizeItems(ExpenseRequest request) {
		List<ExpenseItemRequest> items = request.items();
		if (items == null || items.isEmpty()) {
			if (request.splitMethod() == SplitMethod.EQUAL && request.memberIds() != null
				&& !request.memberIds().isEmpty()) {
				List<ExpenseShareRequest> members = request.memberIds().stream()
					.map(id -> new ExpenseShareRequest(id, null))
					.toList();
				return List.of(new ExpenseItemRequest(SINGLE_ITEM_NAME, null, null, members));
			}
			throw invalid("items", "분담할 사람을 1명 이상 선택해 주세요.");
		}
		if (request.splitMethod() != SplitMethod.ITEM && items.size() != 1) {
			throw invalid("items", "균등·개별 분담은 항목이 1개예요. 여러 항목은 항목별(ITEM)로 나눠 주세요.");
		}
		return items;
	}

	// 항목별 원화 금액. 합은 항상 총액과 같다
	private static List<Long> allocateItems(ExpenseRequest request, Money money, List<ExpenseItemRequest> items) {
		if (request.splitMethod() != SplitMethod.ITEM) {
			return List.of(money.amountKrw());
		}
		if (request.rateMode() == RateMode.KRW) {
			long sum = 0;
			List<Long> amounts = new ArrayList<>();
			for (int i = 0; i < items.size(); i++) {
				Long amount = items.get(i).amountKrw();
				if (amount == null || amount <= 0) {
					throw invalid("items[" + i + "].amountKrw", "항목 금액을 입력해 주세요.");
				}
				amounts.add(amount);
				sum += amount;
			}
			if (sum != money.amountKrw()) {
				throw invalid("items", "항목 금액의 합(" + sum + "원)이 총액(" + money.amountKrw() + "원)과 같아야 해요.");
			}
			return amounts;
		}
		BigDecimal sum = BigDecimal.ZERO;
		List<BigDecimal> amounts = new ArrayList<>();
		for (int i = 0; i < items.size(); i++) {
			BigDecimal amount = items.get(i).amountLocal();
			if (amount == null) {
				throw invalid("items[" + i + "].amountLocal", "항목 금액을 입력해 주세요.");
			}
			amounts.add(amount);
			sum = sum.add(amount);
		}
		if (sum.compareTo(money.amountLocal()) != 0) {
			throw invalid("items", "항목 금액의 합(" + sum.stripTrailingZeros().toPlainString() + ")이 총액("
				+ money.amountLocal().stripTrailingZeros().toPlainString() + ")과 같아야 해요.");
		}
		return ExpenseSplitCalculator.allocateItems(amounts, money.rate(), money.amountKrw());
	}

	private static Map<TripMember, Long> splitItem(SplitMethod method, String path, ExpenseItemRequest item,
		long itemKrw, TripMember payer, Map<UUID, TripMember> members) {
		List<UUID> memberIds = new ArrayList<>();
		Set<UUID> seen = new HashSet<>();
		for (int j = 0; j < item.members().size(); j++) {
			UUID memberId = item.members().get(j).memberId();
			if (!members.containsKey(memberId)) {
				throw invalid(path + ".members[" + j + "].memberId", "이 여행의 멤버만 분담할 수 있어요.");
			}
			if (!seen.add(memberId)) {
				throw invalid(path + ".members[" + j + "].memberId", "같은 사람을 두 번 선택했어요.");
			}
			memberIds.add(memberId);
		}

		Map<TripMember, Long> shares = new LinkedHashMap<>();
		if (method == SplitMethod.CUSTOM) {
			long sum = 0;
			for (int j = 0; j < item.members().size(); j++) {
				Long share = item.members().get(j).shareKrw();
				if (share == null) {
					throw invalid(path + ".members[" + j + "].shareKrw", "분담 금액을 입력해 주세요.");
				}
				shares.put(members.get(memberIds.get(j)), share);
				sum += share;
			}
			if (sum != itemKrw) {
				throw invalid(path + ".members", "개인별 금액의 합(" + sum + "원)이 총액(" + itemKrw + "원)과 같아야 해요.");
			}
			return shares;
		}
		ExpenseSplitCalculator.splitEqually(itemKrw, memberIds, payer.getId())
			.forEach((memberId, share) -> shares.put(members.get(memberId), share));
		return shares;
	}

	private static List<ExpenseItemUser> toShares(ExpenseItem item, Map<TripMember, Long> shares) {
		return shares.entrySet().stream()
			.map(entry -> ExpenseItemUser.builder().item(item).member(entry.getKey())
				.shareKrw(BigDecimal.valueOf(entry.getValue())).build())
			.toList();
	}

	private static String itemName(ExpenseItemRequest item, int index) {
		if (item.name() != null && !item.name().isBlank()) {
			return item.name().trim();
		}
		return index == 0 ? SINGLE_ITEM_NAME : "항목 " + (index + 1);
	}

	private static BaseException invalid(String field, String message) {
		return BaseException.of(ErrorCode.INVALID_EXPENSE, field, message);
	}

	// 금액 계산 결과. KRW 모드면 amountLocal·rate·rateDate가 null
	private record Money(BigDecimal amountLocal, BigDecimal rate, LocalDate rateDate, long amountKrw) {
	}

	private record Plan(Expense expense, List<ItemPlan> items) {
	}

	private record ItemPlan(ExpenseItem item, Map<TripMember, Long> shares) {
	}

	// 지출 목록 커서: "{결제일}_{지출 ID}"
	private record Cursor(LocalDate paidDate, UUID id) {

		private static Cursor parse(String cursor) {
			if (cursor == null || cursor.isBlank()) {
				return new Cursor(null, NO_CURSOR_ID);
			}
			int separator = cursor.indexOf('_');
			try {
				return new Cursor(LocalDate.parse(cursor.substring(0, separator)),
					UUID.fromString(cursor.substring(separator + 1)));
			} catch (DateTimeParseException | IllegalArgumentException | StringIndexOutOfBoundsException e) {
				throw BaseException.of(ErrorCode.VALIDATION_ERROR, "cursor", "목록 위치(cursor)가 올바르지 않아요.");
			}
		}

		private static String of(ExpenseListItemResponse item) {
			return item.paidDate() + "_" + item.id();
		}
	}
}
