package com.backpackcorp.backpack.expense.dto;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.backpackcorp.backpack.expense.domain.Expense;
import com.backpackcorp.backpack.expense.domain.ExpenseCategory;
import com.backpackcorp.backpack.expense.domain.ExpenseItemUser;
import com.backpackcorp.backpack.expense.domain.RateMode;
import com.backpackcorp.backpack.expense.domain.SplitMethod;
import com.backpackcorp.backpack.trip.domain.TripMember;

// 지출 상세. 등록 결과와 미리보기(id·version·시각이 null)가 같은 형식이다.
// memberShares: 사람별 부담 합계 (화면의 "개인별 부담"). shareLocal은 표시용 외화 환산값
public record ExpenseDetailResponse(
	UUID id,
	String title,
	ExpenseCategory category,
	LocalDate paidDate,
	String currencyCode,
	RateMode rateMode,
	BigDecimal amountLocal,
	BigDecimal appliedRate,
	LocalDate rateDate,
	long amountKrw,
	SplitMethod splitMethod,
	MemberRef payer,
	MemberRef creator,
	List<ItemResponse> items,
	List<MemberShareResponse> memberShares,
	Integer version,
	Instant createdAt,
	Instant updatedAt
) {

	// remainderKrw / remainderMember: 균등 분담에서 끝전(남는 원)과 그것을 부담한 사람. 없으면 0 / null
	public record ItemResponse(
		UUID id,
		String name,
		BigDecimal amountLocal,
		long amountKrw,
		int sortOrder,
		long remainderKrw,
		MemberRef remainderMember,
		List<ShareResponse> members
	) {
	}

	public record ShareResponse(
		UUID memberId,
		String name,
		long shareKrw
	) {
	}

	public record MemberShareResponse(
		UUID memberId,
		String name,
		long shareKrw,
		BigDecimal shareLocal,
		boolean isPayer
	) {
	}

	public static ExpenseDetailResponse from(ExpenseBundle bundle) {
		Expense expense = bundle.expense();
		boolean saved = expense.getId() != null;
		String currencyCode = expense.getRateMode() == RateMode.KRW ? "KRW" : expense.getTrip().getCurrencyCode();
		UUID payerId = expense.getPayer().getId();

		Map<UUID, MemberTotal> totals = new LinkedHashMap<>();
		List<ItemResponse> items = bundle.items().stream().map(itemBundle -> {
			List<ShareResponse> shares = itemBundle.shares().stream().map(share -> {
				TripMember member = share.getMember();
				long shareKrw = share.getShareKrw().longValueExact();
				totals.computeIfAbsent(member.getId(), id -> new MemberTotal(member)).add(shareKrw);
				return new ShareResponse(member.getId(), MemberRef.nameOf(member), shareKrw);
			}).toList();
			long itemKrw = itemBundle.item().getAmountKrw().longValueExact();
			Remainder remainder = expense.getSplitMethod() == SplitMethod.CUSTOM
				? Remainder.NONE
				: Remainder.of(itemKrw, itemBundle.shares());
			return new ItemResponse(itemBundle.item().getId(), itemBundle.item().getName(),
				itemBundle.item().getAmountLocal(), itemKrw, itemBundle.item().getSortOrder(), remainder.amountKrw(),
				remainder.member() == null ? null : MemberRef.from(remainder.member()), shares);
		}).toList();

		List<MemberShareResponse> memberShares = totals.values().stream()
			.map(total -> new MemberShareResponse(total.member.getId(), MemberRef.nameOf(total.member), total.shareKrw,
				toLocal(total.shareKrw, expense.getAppliedRate()), total.member.getId().equals(payerId)))
			.toList();

		return new ExpenseDetailResponse(expense.getId(), expense.getTitle(), expense.getCategory(),
			expense.getPaidDate(), currencyCode, expense.getRateMode(), expense.getAmountLocal(),
			expense.getAppliedRate(), expense.getRateDate(), expense.getAmountKrw().longValueExact(),
			expense.getSplitMethod(), MemberRef.from(expense.getPayer()), MemberRef.from(expense.getCreator()), items,
			memberShares, saved ? expense.getVersion() : null, expense.getCreatedAt(), expense.getUpdatedAt());
	}

	private static BigDecimal toLocal(long krw, BigDecimal rate) {
		if (rate == null || rate.signum() == 0) {
			return null;
		}
		return BigDecimal.valueOf(krw).divide(rate, 2, RoundingMode.HALF_UP);
	}

	private static final class MemberTotal {

		private final TripMember member;
		private long shareKrw;

		private MemberTotal(TripMember member) {
			this.member = member;
		}

		private void add(long amount) {
			shareKrw += amount;
		}
	}

	// 저장된 분담액에서 끝전을 되짚는다: 1인 몫(최솟값)보다 많이 낸 한 사람이 끝전 부담자다
	private record Remainder(long amountKrw, TripMember member) {

		private static final Remainder NONE = new Remainder(0, null);

		private static Remainder of(long itemKrw, List<ExpenseItemUser> shares) {
			if (shares.isEmpty()) {
				return NONE;
			}
			long base = shares.stream().mapToLong(share -> share.getShareKrw().longValueExact()).min().orElse(0);
			long remainder = itemKrw - base * shares.size();
			if (remainder <= 0) {
				return NONE;
			}
			TripMember holder = shares.stream()
				.filter(share -> share.getShareKrw().longValueExact() > base)
				.map(ExpenseItemUser::getMember)
				.findFirst()
				.orElse(null);
			return new Remainder(remainder, holder);
		}
	}
}
