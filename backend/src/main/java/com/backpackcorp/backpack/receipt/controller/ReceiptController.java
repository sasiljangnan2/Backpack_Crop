package com.backpackcorp.backpack.receipt.controller;

import java.util.UUID;

import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.receipt.dto.ReceiptScanResponse;
import com.backpackcorp.backpack.receipt.service.ReceiptScanService;

import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}/receipts")
public class ReceiptController {

	private final ReceiptScanService receiptScanService;

	// BP-EX-002 영수증 사진(JPG · PNG, 10MB 이하) → 가게 · 일시 · 항목 · 총액 + 한국어 번역. 사진은 저장하지 않는다
	@PostMapping(path = "/scan", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
	public ReceiptScanResponse scan(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@RequestPart("image") MultipartFile image) {
		return receiptScanService.scan(tripId, BackpackUserDetails.requireId(user), image);
	}
}
