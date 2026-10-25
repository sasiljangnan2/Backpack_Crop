package com.backpackcorp.backpack.expense.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

// 지출 금액 계산 규칙만 모은 순수 함수. DB·스프링 없이 테스트한다.
//
// 원화 환산: amountKrw = round(외화 × 환율), 0.5원은 올린다 (HALF_UP)
// 균등 분담: 1인 몫 = floor(금액 / n). 남는 원(끝전)은 결제자가 부담하고,
//          결제자가 분담 대상이 아니면 대상 목록의 첫 번째 사람이 부담한다
// 항목별 금액: 항목마다 따로 반올림하면 합계가 총액과 1~2원 어긋나므로,
//          내림한 뒤 모자란 원을 소수점 아래가 큰 항목부터 1원씩 채운다 (최대 잉여 방식)
//
// ponytail: 시안 JS는 Math.round(amount / n) 후 차액을 결제자에게 몰아준다. 결과가 다를 수 있으므로
//  앱은 직접 계산하지 말고 POST /expenses/preview 응답을 그대로 보여 준다
public final class ExpenseSplitCalculator {

	private ExpenseSplitCalculator() {
	}

	public static long toKrw(BigDecimal amountLocal, BigDecimal rateToKrw) {
		return amountLocal.multiply(rateToKrw).setScale(0, RoundingMode.HALF_UP).longValueExact();
	}

	// 항목별 외화 금액을 원화로 나눈다. 결과의 합은 항상 totalKrw와 같다
	public static List<Long> allocateItems(List<BigDecimal> itemAmountsLocal, BigDecimal rateToKrw, long totalKrw) {
		int n = itemAmountsLocal.size();
		List<BigDecimal> exact = itemAmountsLocal.stream().map(amount -> amount.multiply(rateToKrw)).toList();
		long[] allocated = new long[n];
		long floorSum = 0;
		for (int i = 0; i < n; i++) {
			allocated[i] = exact.get(i).setScale(0, RoundingMode.FLOOR).longValueExact();
			floorSum += allocated[i];
		}
		long remaining = totalKrw - floorSum;
		if (remaining < 0 || remaining > n) {
			throw new IllegalArgumentException("항목 합계가 총액과 맞지 않습니다: total=" + totalKrw + ", floor=" + floorSum);
		}
		// 소수점 아래가 큰 순서, 같으면 앞 항목부터
		List<Integer> order = new ArrayList<>();
		for (int i = 0; i < n; i++) {
			order.add(i);
		}
		order.sort(Comparator.comparing((Integer i) -> fraction(exact.get(i))).reversed()
			.thenComparing(Comparator.naturalOrder()));
		for (int k = 0; k < remaining; k++) {
			allocated[order.get(k)]++;
		}
		List<Long> result = new ArrayList<>(n);
		for (long value : allocated) {
			result.add(value);
		}
		return result;
	}

	// 균등 분담. 결과는 memberIds 순서를 지키고, 합은 항상 amountKrw와 같다
	public static Map<UUID, Long> splitEqually(long amountKrw, List<UUID> memberIds, UUID payerId) {
		if (memberIds.isEmpty()) {
			throw new IllegalArgumentException("분담 대상이 없습니다");
		}
		if (memberIds.stream().distinct().count() != memberIds.size()) {
			throw new IllegalArgumentException("분담 대상이 중복되었습니다");
		}
		long base = Math.floorDiv(amountKrw, memberIds.size());
		long remainder = amountKrw - base * memberIds.size();
		UUID remainderHolder = remainderHolder(memberIds, payerId);
		Map<UUID, Long> shares = new LinkedHashMap<>();
		for (UUID memberId : memberIds) {
			shares.put(memberId, memberId.equals(remainderHolder) ? base + remainder : base);
		}
		return shares;
	}

	// 끝전을 부담할 사람: 결제자가 대상에 있으면 결제자, 없으면 첫 번째 대상
	public static UUID remainderHolder(List<UUID> memberIds, UUID payerId) {
		return memberIds.contains(payerId) ? payerId : memberIds.getFirst();
	}

	private static BigDecimal fraction(BigDecimal value) {
		return value.subtract(value.setScale(0, RoundingMode.FLOOR));
	}
}
