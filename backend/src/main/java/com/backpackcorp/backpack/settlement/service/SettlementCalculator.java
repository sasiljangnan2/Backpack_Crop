package com.backpackcorp.backpack.settlement.service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;

// 정산 계산만 하는 순수 함수. DB·스프링 없이 테스트한다.
//
// 잔액: balance = 낸 돈 − 부담할 돈 (양수면 받을 사람, 음수면 보낼 사람)
// 송금 경로: 가장 많이 받을 사람과 가장 많이 보낼 사람을 차례로 짝짓는다 (greedy).
//   같은 금액끼리 맞추면 한 번에 둘 다 0이 되므로, 금액이 딱 맞는 쌍이 있으면 그 쌍을 먼저 고른다.
//   송금은 최대 (잔액이 0이 아닌 사람 수 − 1)건이다.
//
// ponytail: 송금 건수를 수학적으로 최소화하는 문제는 NP-hard라 greedy를 쓴다. 여행 인원(10명 안팎)에서는
//  사실상 최소와 같거나 1건 차이다
public final class SettlementCalculator {

	private SettlementCalculator() {
	}

	public record MemberBalance(UUID memberId, long paidKrw, long shareKrw) {

		public long balanceKrw() {
			return paidKrw - shareKrw;
		}
	}

	public record Transfer(UUID fromMemberId, UUID toMemberId, long amountKrw) {
	}

	public record Result(List<MemberBalance> balances, List<Transfer> transfers) {

		public long totalPaidKrw() {
			return balances.stream().mapToLong(MemberBalance::paidKrw).sum();
		}

		public long transferTotalKrw() {
			return transfers.stream().mapToLong(Transfer::amountKrw).sum();
		}
	}

	// memberOrder: 결과에 담을 멤버와 순서 (같은 금액일 때 앞 사람이 먼저 짝지어진다)
	public static Result calculate(List<UUID> memberOrder, Map<UUID, Long> paidKrw, Map<UUID, Long> shareKrw) {
		List<MemberBalance> balances = memberOrder.stream()
			.map(id -> new MemberBalance(id, paidKrw.getOrDefault(id, 0L), shareKrw.getOrDefault(id, 0L)))
			.toList();
		long paidSum = balances.stream().mapToLong(MemberBalance::paidKrw).sum();
		long shareSum = balances.stream().mapToLong(MemberBalance::shareKrw).sum();
		if (paidSum != shareSum) {
			// 지출마다 분담 합계 = 지출 금액으로 저장하므로 다르면 데이터가 깨진 것이다
			throw new IllegalStateException("낸 돈 합계와 부담할 돈 합계가 다릅니다: " + paidSum + " != " + shareSum);
		}

		List<Party> creditors = new ArrayList<>();
		List<Party> debtors = new ArrayList<>();
		for (int i = 0; i < balances.size(); i++) {
			long balance = balances.get(i).balanceKrw();
			if (balance > 0) {
				creditors.add(new Party(balances.get(i).memberId(), i, balance));
			} else if (balance < 0) {
				debtors.add(new Party(balances.get(i).memberId(), i, -balance));
			}
		}

		List<Transfer> transfers = new ArrayList<>();
		while (!creditors.isEmpty() && !debtors.isEmpty()) {
			creditors.sort(Party.LARGEST_FIRST);
			debtors.sort(Party.LARGEST_FIRST);
			Party[] pair = exactPair(creditors, debtors);
			Party creditor = pair != null ? pair[0] : creditors.getFirst();
			Party debtor = pair != null ? pair[1] : debtors.getFirst();
			long amount = Math.min(creditor.amount, debtor.amount);
			transfers.add(new Transfer(debtor.memberId, creditor.memberId, amount));
			creditor.amount -= amount;
			debtor.amount -= amount;
			if (creditor.amount == 0) {
				creditors.remove(creditor);
			}
			if (debtor.amount == 0) {
				debtors.remove(debtor);
			}
		}

		long positiveSum = balances.stream().mapToLong(MemberBalance::balanceKrw).filter(b -> b > 0).sum();
		Result result = new Result(balances, transfers);
		if (result.transferTotalKrw() != positiveSum) {
			throw new IllegalStateException("송금 총액이 받을 돈 합계와 다릅니다: " + result.transferTotalKrw() + " != "
				+ positiveSum);
		}
		return result;
	}

	// 금액이 같은 (받을 사람, 보낼 사람) 쌍. 큰 금액부터 찾는다. 없으면 null
	private static Party[] exactPair(List<Party> creditors, List<Party> debtors) {
		for (Party creditor : creditors) {
			for (Party debtor : debtors) {
				if (creditor.amount == debtor.amount) {
					return new Party[] {creditor, debtor};
				}
			}
		}
		return null;
	}

	private static final class Party {

		// 금액이 큰 순, 같으면 멤버 순서
		private static final Comparator<Party> LARGEST_FIRST = Comparator.comparingLong((Party p) -> p.amount)
			.reversed()
			.thenComparingInt(p -> p.order);

		private final UUID memberId;
		private final int order;
		private long amount;

		private Party(UUID memberId, int order, long amount) {
			this.memberId = memberId;
			this.order = order;
			this.amount = amount;
		}
	}
}
