package com.backpackcorp.backpack.receipt.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

// 영수증에서 읽은 결제 정보 (BP-EX-002 → EX-003). 금액은 영수증 통화(currency) 기준.
// storeKo · nameKo: 한국어가 아닌 글자의 한국어 번역 (이미 한국어면 null). time: "HH:mm" 또는 null.
// taxIncluded가 false면 세금이 항목 금액에 더해진다 (일본 외세: 항목 합계 + tax = total)
public record ReceiptScanResponse(
	String store,
	String storeKo,
	LocalDate date,
	String time,
	String currency,
	List<Item> items,
	BigDecimal subtotal,
	BigDecimal tax,
	boolean taxIncluded,
	BigDecimal total
) {

	// unclear: 글자가 흐려 확인이 필요한 줄
	public record Item(String name, String nameKo, int qty, BigDecimal unitPrice, BigDecimal amount,
		boolean unclear) {
	}
}
