package com.backpackcorp.backpack.settlement.dto;

// 잔액 부호에 따른 표시 상태. 화면 문구("받을 돈" / "보낼 돈" / "정산 완료")에 쓴다
public enum SettlementStatus {
	RECEIVE,
	SEND,
	SETTLED;

	public static SettlementStatus of(long balanceKrw) {
		if (balanceKrw > 0) {
			return RECEIVE;
		}
		return balanceKrw < 0 ? SEND : SETTLED;
	}
}
