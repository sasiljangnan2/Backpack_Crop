package com.backpackcorp.backpack.settlement.service;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.expense.domain.Expense;
import com.backpackcorp.backpack.expense.dto.ExpenseAmountDto;
import com.backpackcorp.backpack.expense.dto.ExpenseTotalsDto;
import com.backpackcorp.backpack.expense.dto.MemberAmountDto;
import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.expense.repository.ExpenseItemUserRepository;
import com.backpackcorp.backpack.expense.repository.ExpenseRepository;
import com.backpackcorp.backpack.fund.repository.FundContributionRepository;
import com.backpackcorp.backpack.settlement.dto.MySettlementResponse;
import com.backpackcorp.backpack.settlement.dto.MySettlementResponse.Direction;
import com.backpackcorp.backpack.settlement.dto.MySettlementResponse.ExpenseLine;
import com.backpackcorp.backpack.settlement.dto.MySettlementResponse.MyTransferResponse;
import com.backpackcorp.backpack.settlement.dto.SettlementResponse;
import com.backpackcorp.backpack.settlement.dto.SettlementStatus;
import com.backpackcorp.backpack.settlement.service.SettlementCalculator.MemberBalance;
import com.backpackcorp.backpack.settlement.service.SettlementCalculator.Result;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.RequiredArgsConstructor;

// 정산은 저장하지 않고 요청 때마다 지출에서 계산한다 (지출이 바뀌면 바로 반영된다)
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SettlementService {

	private final TripMemberGuard tripMemberGuard;
	private final TripMemberRepository tripMemberRepository;
	private final ExpenseRepository expenseRepository;
	private final ExpenseItemUserRepository expenseItemUserRepository;
	private final FundContributionRepository fundContributionRepository;
	private final Clock clock;

	public SettlementResponse getSettlement(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Calculation calculation = calculate(tripId);

		List<SettlementResponse.MemberResponse> members = calculation.result().balances().stream()
			.filter(balance -> !MemberRef.FUND_ID.equals(balance.memberId()))
			.map(balance -> {
				TripMember member = calculation.members().get(balance.memberId());
				return new SettlementResponse.MemberResponse(member.getId(), MemberRef.nameOf(member),
					member.getId().equals(me.getId()), member.getLeftAt() != null, balance.paidKrw(),
					calculation.contributed().getOrDefault(member.getId(), 0L), balance.shareKrw(), balance.balanceKrw(),
					SettlementStatus.of(balance.balanceKrw()));
			})
			.toList();
		List<SettlementResponse.TransferResponse> transfers = calculation.result().transfers().stream()
			.map(transfer -> new SettlementResponse.TransferResponse(calculation.ref(transfer.fromMemberId()),
				calculation.ref(transfer.toMemberId()), transfer.amountKrw()))
			.toList();
		long directTransferCount = expenseItemUserRepository.findDebtPairs(tripId).size();
		return new SettlementResponse(calculation.totalKrw(), calculation.expenseCount(),
			calculation.result().transferTotalKrw(), directTransferCount, members, transfers, calculation.fund(),
			Instant.now(clock));
	}

	public MySettlementResponse getMySettlement(UUID tripId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Calculation calculation = calculate(tripId);
		MemberBalance mine = calculation.result().balances().stream()
			.filter(balance -> balance.memberId().equals(me.getId()))
			.findFirst()
			.orElse(new MemberBalance(me.getId(), 0, 0));

		List<MyTransferResponse> transfers = calculation.result().transfers().stream()
			.filter(t -> t.fromMemberId().equals(me.getId()) || t.toMemberId().equals(me.getId()))
			.map(t -> t.fromMemberId().equals(me.getId())
				? new MyTransferResponse(Direction.SEND, calculation.ref(t.toMemberId()), t.amountKrw())
				: new MyTransferResponse(Direction.RECEIVE, calculation.ref(t.fromMemberId()), t.amountKrw()))
			.toList();

		List<Expense> involving = expenseRepository.findInvolving(tripId, me.getId());
		Map<UUID, Long> myShares = involving.isEmpty() ? Map.of() : expenseItemUserRepository
			.sumShareByExpense(me.getId(), involving.stream().map(Expense::getId).toList()).stream()
			.collect(Collectors.toMap(ExpenseAmountDto::expenseId, ExpenseAmountDto::amount));
		List<ExpenseLine> expenses = involving.stream().map(expense -> {
			boolean paidByMe = !expense.isPaidFromFund() && expense.getPayer().getId().equals(me.getId());
			long amount = expense.getAmountKrw().longValueExact();
			long paid = paidByMe ? amount : 0;
			long share = myShares.getOrDefault(expense.getId(), 0L);
			return new ExpenseLine(expense.getId(), expense.getTitle(), expense.getCategory(), expense.getPaidDate(),
				amount, expense.isPaidFromFund() ? MemberRef.FUND : MemberRef.from(expense.getPayer()), paidByMe, paid,
				share, paid - share);
		}).toList();

		return new MySettlementResponse(MemberRef.from(me), mine.paidKrw(),
			calculation.contributed().getOrDefault(me.getId(), 0L), mine.shareKrw(), mine.balanceKrw(),
			SettlementStatus.of(mine.balanceKrw()), calculation.totalKrw(), calculation.expenseCount(),
			transfers, expenses, Instant.now(clock));
	}

	// 현재 멤버는 모두, 나간 멤버는 지출 기록이 있을 때만 포함한다.
	// 공금은 가상의 멤버로 계산에 넣는다: 공금 지출을 "낸 돈", 멤버가 모은 돈을 "부담할 돈"으로 친다.
	// 멤버 쪽에서는 모은 돈이 낸 돈이라, 남은 공금은 "공금 → 멤버" 송금으로 나온다
	private Calculation calculate(UUID tripId) {
		Map<UUID, Long> paid = expenseRepository.sumPaidByMember(tripId).stream()
			.collect(Collectors.toMap(MemberAmountDto::memberId, MemberAmountDto::amount, Long::sum, HashMap::new));
		Map<UUID, Long> contributed = fundContributionRepository.sumByMember(tripId).stream()
			.collect(Collectors.toMap(MemberAmountDto::memberId, MemberAmountDto::amount));
		contributed.forEach((memberId, amount) -> paid.merge(memberId, amount, Long::sum));
		Map<UUID, Long> share = expenseItemUserRepository.sumShareByMember(tripId).stream()
			.collect(Collectors.toMap(MemberAmountDto::memberId, MemberAmountDto::amount, Long::sum, HashMap::new));
		List<TripMember> members = tripMemberRepository.findAllWithUserByTripId(tripId).stream()
			.filter(member -> member.getLeftAt() == null || paid.containsKey(member.getId())
				|| share.containsKey(member.getId()))
			.toList();
		List<UUID> order = new ArrayList<>(members.stream().map(TripMember::getId).toList());
		long collected = contributed.values().stream().mapToLong(Long::longValue).sum();
		long spent = expenseRepository.sumFundSpent(tripId, null).longValueExact();
		SettlementResponse.FundSummary fund = null;
		if (collected > 0 || spent > 0) {
			order.add(MemberRef.FUND_ID);
			paid.put(MemberRef.FUND_ID, spent);
			share.put(MemberRef.FUND_ID, collected);
			fund = new SettlementResponse.FundSummary(collected, spent, collected - spent);
		}
		Result result = SettlementCalculator.calculate(order, paid, share);
		ExpenseTotalsDto totals = expenseRepository.sumByTrip(tripId, null, null);
		Map<UUID, TripMember> byId = members.stream()
			.collect(Collectors.toMap(TripMember::getId, Function.identity()));
		return new Calculation(byId, result, totals.totalValue(), totals.countValue(), contributed, fund);
	}

	private record Calculation(Map<UUID, TripMember> members, Result result, long totalKrw, long expenseCount,
		Map<UUID, Long> contributed, SettlementResponse.FundSummary fund) {

		private MemberRef ref(UUID memberId) {
			return MemberRef.FUND_ID.equals(memberId) ? MemberRef.FUND : MemberRef.from(members.get(memberId));
		}
	}
}
