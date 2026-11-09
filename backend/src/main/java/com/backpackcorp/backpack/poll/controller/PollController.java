package com.backpackcorp.backpack.poll.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.backpackcorp.backpack.global.security.BackpackUserDetails;
import com.backpackcorp.backpack.poll.domain.PollStatus;
import com.backpackcorp.backpack.poll.dto.PollCloseRequest;
import com.backpackcorp.backpack.poll.dto.PollCreateRequest;
import com.backpackcorp.backpack.poll.dto.PollResponse;
import com.backpackcorp.backpack.poll.dto.PollVoteRequest;
import com.backpackcorp.backpack.poll.service.PollService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/trips/{tripId}/polls")
public class PollController {

	private final PollService pollService;

	// ?status=OPEN|CLOSED (생략하면 전체), 최신순
	@GetMapping
	public List<PollResponse> getPolls(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@RequestParam(required = false) PollStatus status) {
		return pollService.getPolls(tripId, BackpackUserDetails.requireId(user), status);
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public PollResponse createPoll(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@Valid @RequestBody PollCreateRequest request) {
		return pollService.createPoll(tripId, BackpackUserDetails.requireId(user), request);
	}

	@GetMapping("/{pollId}")
	public PollResponse getPoll(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID pollId) {
		return pollService.getPoll(tripId, pollId, BackpackUserDetails.requireId(user));
	}

	// 1인 1표. 이미 투표했으면 후보만 바꾼다
	@PutMapping("/{pollId}/votes/me")
	public PollResponse vote(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID pollId, @Valid @RequestBody PollVoteRequest request) {
		return pollService.vote(tripId, pollId, BackpackUserDetails.requireId(user), request.optionId());
	}

	@DeleteMapping("/{pollId}/votes/me")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void cancelVote(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID pollId) {
		pollService.cancelVote(tripId, pollId, BackpackUserDetails.requireId(user));
	}

	// 만든 사람 · 방장만
	@PostMapping("/{pollId}/close")
	public PollResponse close(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID pollId, @RequestBody(required = false) PollCloseRequest request) {
		return pollService.close(tripId, pollId, BackpackUserDetails.requireId(user),
			request == null ? null : request.selectedOptionId());
	}

	@DeleteMapping("/{pollId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void deletePoll(@AuthenticationPrincipal BackpackUserDetails user, @PathVariable UUID tripId,
		@PathVariable UUID pollId) {
		pollService.deletePoll(tripId, pollId, BackpackUserDetails.requireId(user));
	}
}
