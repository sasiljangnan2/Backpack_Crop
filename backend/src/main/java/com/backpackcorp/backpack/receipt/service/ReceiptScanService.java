package com.backpackcorp.backpack.receipt.service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Currency;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.multipart.MultipartFile;

import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.global.storage.ImageStorage;
import com.backpackcorp.backpack.receipt.dto.ReceiptScanResponse;
import com.backpackcorp.backpack.replan.service.GeminiClient;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import lombok.extern.slf4j.Slf4j;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

// 영수증 사진을 Gemini(무료 등급)에 보내 가게 · 일시 · 항목 · 총액을 읽고, 외국어는 한국어 번역을 붙인다.
// 기기 안 OCR(ML Kit)보다 일본어 · 중국어 영수증을 훨씬 잘 읽는다 (여러 줄 항목, "*298" 같은 세율 표시, 외세).
// 실패하면 오류로 답하고 앱이 기기 안 OCR 결과를 쓴다. 사진은 저장하지 않는다
@Slf4j
@Service
public class ReceiptScanService {

	static final String INSTRUCTION = """
		You read a photo of a shop receipt for a travel expense app used by Koreans. Reply with JSON only.

		Fields:
		- store: the shop name as printed (brand + branch if shown, e.g. "セブン-イレブン Kiosk高松駅店").
		  Never use the address, phone or company registration number.
		- storeKo: natural Korean for the store name (brand names in their usual Korean spelling,
		  e.g. "세븐일레븐 키오스크 다카마쓰역점"). Empty string if the store name is already Korean.
		- date: YYYY-MM-DD, time: HH:MM (24h). Empty string if not printed.
		- currency: ISO 4217 code of the amounts (JPY, KRW, USD, EUR, TWD, THB, VND ...).
		- items: every purchased product line, top to bottom. For each:
		  - name: product name exactly as printed in the original language (fix only broken characters; keep codes like "7P").
		  - nameKo: short natural Korean saying what the product is. Translate the meaning (도시락, 주먹밥, 컵라면, 맥주 ...),
		    write brand names in Korean spelling. Empty string if the name is already Korean.
		  - qty: quantity. A line like "@240 x 3" or "240円 × 3" under or next to a name means unit price 240 and qty 3
		    for that product. Default 1.
		  - unitPrice: price of one unit.
		  - amount: the line total printed for the product (unitPrice × qty).
		  - A "*", "※", "#", "軽" or "8%" mark next to a price is a tax-rate marker, NOT a quantity. "*298" means 298.
		  - A discount printed under a product (値引, 割引, 할인, discount) is its own item with a negative amount.
		  - unclear: true only if the name or price was hard to read.
		- Do not list subtotal, tax, total, payment, change, points, address, phone, registration or slip numbers as items.
		- subtotal: the printed subtotal (小計 / 소계 / subtotal), 0 if none.
		- tax: the consumption tax / VAT amount printed (消費税等, 内消費税, 부가세, tax), 0 if none.
		- taxIncluded: true if item prices already include the tax (内税, 税込, "(内消費税"),
		  false if the tax is added on top of the item prices (外税, 税抜, subtotal + tax = total).
		- total: the amount actually paid (合計 / 합계 / total). Thousands separators may look like "." or ",":
		  "¥3.022" is 3022 for JPY and KRW.
		Use only what is printed. Do not invent items. Write numbers without separators.
		If the photo is not a receipt, return total 0 and no items.
		""";

	private static final Map<String, Object> SCHEMA = schema();
	private static final Pattern TIME = Pattern.compile("^([01]?\\d|2[0-3]):([0-5]\\d)");
	private static final Pattern CURRENCY = Pattern.compile("^[A-Z]{3}$");
	private static final Pattern HANGUL = Pattern.compile("[가-힣]");
	// 한국어 이름에 섞여 있으면 번역이 필요한 글자 (가나 · 한자 · 태국 문자 등. 영문은 한국 가게 이름에도 흔하다)
	private static final Pattern FOREIGN_SCRIPT = Pattern.compile(
		"[\\p{IsHiragana}\\p{IsKatakana}\\p{IsHan}\\p{IsThai}\\p{IsCyrillic}\\p{IsArabic}]");
	private static final int MAX_NAME = 100;
	private static final int MAX_QTY = 999;

	private final GeminiClient gemini;
	private final TripMemberGuard tripMemberGuard;
	private final JsonMapper jsonMapper;
	private final TransactionTemplate readTransaction;

	public ReceiptScanService(GeminiClient gemini, TripMemberGuard tripMemberGuard, JsonMapper jsonMapper,
		PlatformTransactionManager transactionManager) {
		this.gemini = gemini;
		this.tripMemberGuard = tripMemberGuard;
		this.jsonMapper = jsonMapper;
		this.readTransaction = new TransactionTemplate(transactionManager);
		this.readTransaction.setReadOnly(true);
	}

	// Gemini를 기다리는 동안 DB 연결을 잡지 않도록 여행 통화만 짧은 트랜잭션에서 읽는다
	public ReceiptScanResponse scan(UUID tripId, UUID userId, MultipartFile image) {
		String tripCurrency = readTransaction.execute(
			status -> tripMemberGuard.requireMember(tripId, userId).getTrip().getCurrencyCode());
		String mimeType = ImageStorage.mimeTypeOf(image);
		if (!gemini.enabled()) {
			throw new BaseException(ErrorCode.RECEIPT_AI_UNAVAILABLE);
		}
		byte[] bytes;
		try {
			bytes = image.getBytes();
		} catch (IOException e) {
			throw new UncheckedIOException(e);
		}
		String answer;
		try {
			answer = gemini.generateJson(INSTRUCTION,
				List.of(GeminiClient.imagePart(mimeType, bytes), Map.of("text", "여행 통화: " + tripCurrency)),
				SCHEMA, 0.1);
		} catch (RuntimeException e) {
			log.warn("영수증 읽기 실패 (Gemini): {}", e.getMessage());
			throw new BaseException(ErrorCode.RECEIPT_AI_FAILED);
		}
		AiReceipt receipt;
		try {
			receipt = jsonMapper.readValue(answer, AiReceipt.class);
		} catch (JacksonException e) {
			log.warn("영수증 읽기 실패 (형식): {}", e.getOriginalMessage());
			throw new BaseException(ErrorCode.RECEIPT_AI_FAILED);
		}
		return normalize(receipt, tripCurrency);
	}

	// Gemini 답을 앱이 그대로 쓸 수 있게 다듬는다: 통화 소수 자리로 반올림, 빈 줄 · 0원 줄 빼기,
	// 할인 줄은 바로 위 항목에서 빼기, 원문과 같은 번역은 지우기
	static ReceiptScanResponse normalize(AiReceipt receipt, String tripCurrency) {
		String currency = text(receipt.currency(), 3);
		currency = currency != null && CURRENCY.matcher(currency.toUpperCase(Locale.ROOT)).matches()
			? currency.toUpperCase(Locale.ROOT)
			: tripCurrency;
		int scale = scaleOf(currency);
		BigDecimal total = money(receipt.total(), scale);
		if (total == null || total.signum() <= 0) {
			throw new BaseException(ErrorCode.RECEIPT_UNREADABLE);
		}

		List<ReceiptScanResponse.Item> items = new ArrayList<>();
		for (AiItem item : receipt.items() == null ? List.<AiItem>of() : receipt.items()) {
			String name = text(item.name(), MAX_NAME);
			BigDecimal amount = money(item.amount(), scale);
			if (name == null || amount == null || amount.signum() == 0) {
				continue;
			}
			if (amount.signum() < 0) {
				// 할인: 바로 위 항목 금액에서 뺀다. 위 항목보다 크면 버린다 (총액은 영수증에 적힌 값을 쓴다)
				if (!items.isEmpty()) {
					ReceiptScanResponse.Item last = items.getLast();
					BigDecimal discounted = last.amount().add(amount);
					if (discounted.signum() > 0) {
						items.set(items.size() - 1, new ReceiptScanResponse.Item(last.name(), last.nameKo(), last.qty(),
							discounted.divide(BigDecimal.valueOf(last.qty()), scale, RoundingMode.HALF_UP), discounted,
							last.unclear()));
					}
				}
				continue;
			}
			int qty = item.qty() == null || item.qty() < 1 || item.qty() > MAX_QTY ? 1 : item.qty();
			BigDecimal unitPrice = money(item.unitPrice(), scale);
			if (unitPrice == null || unitPrice.signum() <= 0) {
				unitPrice = amount.divide(BigDecimal.valueOf(qty), scale, RoundingMode.HALF_UP);
			}
			items.add(new ReceiptScanResponse.Item(name, translation(name, item.nameKo()), qty, unitPrice, amount,
				Boolean.TRUE.equals(item.unclear())));
		}

		String store = text(receipt.store(), MAX_NAME);
		BigDecimal tax = money(receipt.tax(), scale);
		BigDecimal subtotal = money(receipt.subtotal(), scale);
		return new ReceiptScanResponse(store, store == null ? null : translation(store, receipt.storeKo()),
			dateOf(receipt.date()), timeOf(receipt.time()), currency, items,
			subtotal == null || subtotal.signum() <= 0 ? null : subtotal,
			tax == null || tax.signum() < 0 ? BigDecimal.ZERO.setScale(scale) : tax,
			receipt.taxIncluded() == null || receipt.taxIncluded(), total);
	}

	// 원문이 한국어거나 번역이 원문과 같으면 null
	private static String translation(String original, String korean) {
		String ko = text(korean, MAX_NAME);
		if (ko == null || ko.equalsIgnoreCase(original) || !HANGUL.matcher(ko).find()) {
			return null;
		}
		if (HANGUL.matcher(original).find() && !FOREIGN_SCRIPT.matcher(original).find()) {
			return null;
		}
		return ko;
	}

	private static String text(String value, int max) {
		if (value == null || value.isBlank()) {
			return null;
		}
		String trimmed = value.strip().replaceAll("\\s+", " ");
		return trimmed.length() > max ? trimmed.substring(0, max) : trimmed;
	}

	private static BigDecimal money(BigDecimal value, int scale) {
		return value == null ? null : value.setScale(scale, RoundingMode.HALF_UP);
	}

	private static int scaleOf(String currency) {
		try {
			int digits = Currency.getInstance(currency).getDefaultFractionDigits();
			return digits < 0 ? 2 : Math.min(digits, 2);
		} catch (IllegalArgumentException e) {
			return 2;
		}
	}

	private static LocalDate dateOf(String value) {
		if (value == null || value.isBlank()) {
			return null;
		}
		try {
			return LocalDate.parse(value.strip());
		} catch (DateTimeParseException e) {
			return null;
		}
	}

	private static String timeOf(String value) {
		Matcher m = value == null ? null : TIME.matcher(value.strip());
		if (m == null || !m.find()) {
			return null;
		}
		return String.format("%02d:%s", Integer.parseInt(m.group(1)), m.group(2));
	}

	private static Map<String, Object> schema() {
		Map<String, Object> item = Map.of(
			"type", "OBJECT",
			"properties", Map.of(
				"name", Map.of("type", "STRING"),
				"nameKo", Map.of("type", "STRING"),
				"qty", Map.of("type", "INTEGER"),
				"unitPrice", Map.of("type", "NUMBER"),
				"amount", Map.of("type", "NUMBER"),
				"unclear", Map.of("type", "BOOLEAN")),
			"required", List.of("name", "nameKo", "qty", "amount"));
		return Map.of(
			"type", "OBJECT",
			"properties", Map.of(
				"store", Map.of("type", "STRING"),
				"storeKo", Map.of("type", "STRING"),
				"date", Map.of("type", "STRING"),
				"time", Map.of("type", "STRING"),
				"currency", Map.of("type", "STRING"),
				"items", Map.of("type", "ARRAY", "items", item),
				"subtotal", Map.of("type", "NUMBER"),
				"tax", Map.of("type", "NUMBER"),
				"taxIncluded", Map.of("type", "BOOLEAN"),
				"total", Map.of("type", "NUMBER")),
			"required", List.of("store", "storeKo", "currency", "items", "tax", "taxIncluded", "total"));
	}

	@JsonIgnoreProperties(ignoreUnknown = true)
	record AiReceipt(String store, String storeKo, String date, String time, String currency, List<AiItem> items,
		BigDecimal subtotal, BigDecimal tax, Boolean taxIncluded, BigDecimal total) {
	}

	@JsonIgnoreProperties(ignoreUnknown = true)
	record AiItem(String name, String nameKo, Integer qty, BigDecimal unitPrice, BigDecimal amount, Boolean unclear) {
	}
}
