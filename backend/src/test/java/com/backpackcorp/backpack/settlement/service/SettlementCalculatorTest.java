package com.backpackcorp.backpack.settlement.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.backpackcorp.backpack.expense.service.ExpenseSplitCalculator;
import com.backpackcorp.backpack.settlement.service.SettlementCalculator.MemberBalance;
import com.backpackcorp.backpack.settlement.service.SettlementCalculator.Result;
import com.backpackcorp.backpack.settlement.service.SettlementCalculator.Transfer;

class SettlementCalculatorTest {

	private final UUID a = UUID.randomUUID();
	private final UUID b = UUID.randomUUID();
	private final UUID c = UUID.randomUUID();
	private final UUID d = UUID.randomUUID();
	private final UUID e = UUID.randomUUID();

	@Test
	void 잔액은_낸_돈에서_부담할_돈을_뺀_값이다() {
		Result result = SettlementCalculator.calculate(List.of(a, b, c),
			Map.of(a, 30_000L), Map.of(a, 10_000L, b, 10_000L, c, 10_000L));

		assertThat(result.balances()).extracting(MemberBalance::balanceKrw).containsExactly(20_000L, -10_000L, -10_000L);
		assertThat(result.transfers()).containsExactlyInAnyOrder(
			new Transfer(b, a, 10_000), new Transfer(c, a, 10_000));
	}

	@Test
	void 끝전이_있는_균등_분담도_송금_총액이_받을_돈의_합과_같다() {
		// given c가 45,348원을 내고 5명이 나눔 (c 9,072원, 나머지 9,069원)
		Map<UUID, Long> share = ExpenseSplitCalculator.splitEqually(45_348, List.of(a, b, c, d, e), c);

		// when
		Result result = SettlementCalculator.calculate(List.of(a, b, c, d, e), Map.of(c, 45_348L), share);

		// then c가 받을 돈 = 45,348 − 9,072 = 36,276원 = 네 명이 9,069원씩
		assertThat(result.transferTotalKrw()).isEqualTo(36_276);
		assertThat(result.transfers()).hasSize(4).allMatch(t -> t.toMemberId().equals(c) && t.amountKrw() == 9_069);
	}

	@Test
	void 결제자가_분담_대상에서_빠져도_정산이_맞는다() {
		// given a가 10,000원을 냈지만 b, c, d만 나눈다 (b가 끝전)
		Map<UUID, Long> share = ExpenseSplitCalculator.splitEqually(10_000, List.of(b, c, d), a);

		// when
		Result result = SettlementCalculator.calculate(List.of(a, b, c, d), Map.of(a, 10_000L), share);

		// then a는 전액을 돌려받는다
		assertThat(result.balances().getFirst().balanceKrw()).isEqualTo(10_000);
		assertThat(result.transfers()).containsExactly(
			new Transfer(b, a, 3_334), new Transfer(c, a, 3_333), new Transfer(d, a, 3_333));
	}

	@Test
	void 금액이_딱_맞는_상대를_먼저_짝지어_송금_건수를_줄인다() {
		// given 받을 사람 a +5,000 / b +4,000, 보낼 사람 c −4,000 / d −3,000 / e −2,000
		Map<UUID, Long> paid = Map.of(a, 5_000L, b, 4_000L);
		Map<UUID, Long> share = Map.of(c, 4_000L, d, 3_000L, e, 2_000L);

		// when
		Result result = SettlementCalculator.calculate(List.of(a, b, c, d, e), paid, share);

		// then 3건. 큰 금액끼리만 짝지으면 c→a 4,000, d→b 3,000, e→a 1,000, e→b 1,000 으로 4건이 된다
		assertThat(result.transfers()).containsExactly(
			new Transfer(c, b, 4_000), new Transfer(d, a, 3_000), new Transfer(e, a, 2_000));
	}

	@Test
	void 여러_지출이_섞여도_송금은_인원수_빼기_1건_이하이고_모두_0이_된다() {
		// given 다섯 명이 번갈아 낸 지출 네 건
		Map<UUID, Long> paid = new HashMap<>();
		Map<UUID, Long> share = new HashMap<>();
		List<UUID> all = List.of(a, b, c, d, e);
		addExpense(paid, share, a, 213_457, all);
		addExpense(paid, share, b, 98_000, List.of(a, b, c));
		addExpense(paid, share, c, 1_234_567, all);
		addExpense(paid, share, d, 45_348, List.of(b, c, d, e));

		// when
		Result result = SettlementCalculator.calculate(all, paid, share);

		// then
		long positive = result.balances().stream().mapToLong(MemberBalance::balanceKrw).filter(x -> x > 0).sum();
		assertThat(result.transferTotalKrw()).isEqualTo(positive);
		assertThat(result.transfers().size()).isLessThanOrEqualTo(all.size() - 1);
		Map<UUID, Long> after = new HashMap<>();
		result.balances().forEach(balance -> after.put(balance.memberId(), balance.balanceKrw()));
		result.transfers().forEach(t -> {
			after.merge(t.fromMemberId(), t.amountKrw(), Long::sum);
			after.merge(t.toMemberId(), -t.amountKrw(), Long::sum);
		});
		assertThat(after.values()).containsOnly(0L);
	}

	@Test
	void 지출이_없으면_송금도_없다() {
		Result result = SettlementCalculator.calculate(List.of(a, b), Map.of(), Map.of());

		assertThat(result.transfers()).isEmpty();
		assertThat(result.balances()).extracting(MemberBalance::balanceKrw).containsOnly(0L);
	}

	@Test
	void 낸_돈과_부담할_돈의_합계가_다르면_계산하지_않는다() {
		assertThatThrownBy(() -> SettlementCalculator.calculate(List.of(a, b), Map.of(a, 100L), Map.of(b, 99L)))
			.isInstanceOf(IllegalStateException.class);
	}

	private static void addExpense(Map<UUID, Long> paid, Map<UUID, Long> share, UUID payer, long amount,
		List<UUID> members) {
		paid.merge(payer, amount, Long::sum);
		ExpenseSplitCalculator.splitEqually(amount, members, payer).forEach((id, s) -> share.merge(id, s, Long::sum));
	}
}
