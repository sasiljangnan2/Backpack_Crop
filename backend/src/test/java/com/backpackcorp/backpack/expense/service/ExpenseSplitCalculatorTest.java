package com.backpackcorp.backpack.expense.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;

class ExpenseSplitCalculatorTest {

	private final UUID a = UUID.randomUUID();
	private final UUID b = UUID.randomUUID();
	private final UUID c = UUID.randomUUID();
	private final UUID d = UUID.randomUUID();
	private final UUID e = UUID.randomUUID();

	@Test
	void 원화_환산은_반올림한다() {
		// 4,850엔 × 9.35 = 45,347.5원 → 45,348원
		assertThat(ExpenseSplitCalculator.toKrw(new BigDecimal("4850.00"), new BigDecimal("9.350000")))
			.isEqualTo(45_348);
		assertThat(ExpenseSplitCalculator.toKrw(new BigDecimal("1.00"), new BigDecimal("9.344999"))).isEqualTo(9);
	}

	@Test
	void 균등_분담의_끝전은_결제자가_부담한다() {
		// given 45,348원을 5명이 나눈다 → 1인 9,069원, 끝전 3원
		// when 결제자는 c
		Map<UUID, Long> shares = ExpenseSplitCalculator.splitEqually(45_348, List.of(a, b, c, d, e), c);

		// then
		assertThat(shares).containsEntry(a, 9_069L).containsEntry(b, 9_069L).containsEntry(c, 9_072L)
			.containsEntry(d, 9_069L).containsEntry(e, 9_069L);
		assertThat(shares.values().stream().mapToLong(Long::longValue).sum()).isEqualTo(45_348);
		assertThat(shares.keySet()).containsExactly(a, b, c, d, e);
	}

	@Test
	void 결제자가_분담_대상이_아니면_첫_번째_대상이_끝전을_부담한다() {
		Map<UUID, Long> shares = ExpenseSplitCalculator.splitEqually(10_000, List.of(b, c, d), a);

		assertThat(shares).containsEntry(b, 3_334L).containsEntry(c, 3_333L).containsEntry(d, 3_333L);
		assertThat(ExpenseSplitCalculator.remainderHolder(List.of(b, c, d), a)).isEqualTo(b);
	}

	@Test
	void 나누어떨어지면_끝전이_없다() {
		assertThat(ExpenseSplitCalculator.splitEqually(9_000, List.of(a, b, c), a).values())
			.containsOnly(3_000L);
	}

	@Test
	void 분담_대상이_없거나_중복되면_거부한다() {
		assertThatThrownBy(() -> ExpenseSplitCalculator.splitEqually(1_000, List.of(), a))
			.isInstanceOf(IllegalArgumentException.class);
		assertThatThrownBy(() -> ExpenseSplitCalculator.splitEqually(1_000, List.of(a, a), a))
			.isInstanceOf(IllegalArgumentException.class);
	}

	@Test
	void 항목별_원화_합계는_총액과_같다() {
		// given 100.04엔 세 항목, 환율 9.35 → 항목마다 935.374원, 총액 300.12엔 = 2,806.122원 → 2,806원
		BigDecimal item = new BigDecimal("100.04");
		BigDecimal rate = new BigDecimal("9.350000");
		long total = ExpenseSplitCalculator.toKrw(new BigDecimal("300.12"), rate);

		// when
		List<Long> allocated = ExpenseSplitCalculator.allocateItems(List.of(item, item, item), rate, total);

		// then 항목마다 반올림하면 935 × 3 = 2,805원으로 총액과 1원 어긋난다. 모자란 1원은 앞 항목이 맡는다
		assertThat(total).isEqualTo(2_806);
		assertThat(allocated).containsExactly(936L, 935L, 935L);
		assertThat(allocated.stream().mapToLong(Long::longValue).sum()).isEqualTo(total);
	}
}
