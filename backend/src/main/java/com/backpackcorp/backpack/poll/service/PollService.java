package com.backpackcorp.backpack.poll.service;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.backpackcorp.backpack.expense.dto.MemberRef;
import com.backpackcorp.backpack.global.exception.BaseException;
import com.backpackcorp.backpack.global.exception.ErrorCode;
import com.backpackcorp.backpack.notification.domain.NotificationRefType;
import com.backpackcorp.backpack.notification.domain.NotificationType;
import com.backpackcorp.backpack.notification.dto.TripNotificationEvent;
import com.backpackcorp.backpack.poll.domain.Poll;
import com.backpackcorp.backpack.poll.domain.PollOption;
import com.backpackcorp.backpack.poll.domain.PollStatus;
import com.backpackcorp.backpack.poll.domain.PollVote;
import com.backpackcorp.backpack.poll.dto.PollCreateRequest;
import com.backpackcorp.backpack.poll.dto.PollResponse;
import com.backpackcorp.backpack.poll.repository.PollOptionRepository;
import com.backpackcorp.backpack.poll.repository.PollRepository;
import com.backpackcorp.backpack.poll.repository.PollVoteRepository;
import com.backpackcorp.backpack.schedule.domain.Schedule;
import com.backpackcorp.backpack.schedule.service.ScheduleService;
import com.backpackcorp.backpack.trip.domain.Trip;
import com.backpackcorp.backpack.trip.domain.TripMember;
import com.backpackcorp.backpack.trip.repository.TripMemberRepository;
import com.backpackcorp.backpack.trip.service.TripMemberGuard;

import lombok.RequiredArgsConstructor;

// 장소 투표 (BP-VT). 1인 1표, 다시 투표하면 후보만 바뀐다.
// 마감할 때 후보를 고르면 그 후보로 슬롯에 일정을 만든다 (일정과 같은 겹침 · 기간 검사)
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PollService {

	private final TripMemberGuard tripMemberGuard;
	private final TripMemberRepository tripMemberRepository;
	private final PollRepository pollRepository;
	private final PollOptionRepository pollOptionRepository;
	private final PollVoteRepository pollVoteRepository;
	private final ScheduleService scheduleService;
	private final ApplicationEventPublisher eventPublisher;
	private final Clock clock;

	public List<PollResponse> getPolls(UUID tripId, UUID userId, PollStatus status) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		List<Poll> polls = pollRepository.findByTrip(tripId).stream()
			.filter(poll -> status == null || poll.getStatus() == status)
			.toList();
		return toResponses(polls, me);
	}

	public PollResponse getPoll(UUID tripId, UUID pollId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		return toResponses(List.of(findPoll(tripId, pollId)), me).getFirst();
	}

	@Transactional
	public PollResponse createPoll(UUID tripId, UUID userId, PollCreateRequest request) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Trip trip = me.getTrip();
		if (!trip.contains(request.slotDate())) {
			throw BaseException.of(ErrorCode.SCHEDULE_OUT_OF_TRIP, "slotDate",
				trip.getStartDate() + " ~ " + trip.getEndDate() + " 사이의 날짜를 선택해 주세요.");
		}
		if (!request.slotEnd().isAfter(request.slotStart())) {
			throw BaseException.of(ErrorCode.INVALID_TIME_RANGE, "slotEnd", "종료 시간은 시작 시간보다 늦어야 해요.");
		}
		if (request.deadlineAt() != null && !request.deadlineAt().isAfter(Instant.now(clock))) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "deadlineAt", "마감 시간은 지금 이후로 정해 주세요.");
		}
		scheduleService.requireFreeSlot(trip.getId(), request.slotDate(),
			request.slotStart().truncatedTo(ChronoUnit.MINUTES), request.slotEnd().truncatedTo(ChronoUnit.MINUTES));
		long distinct = request.options().stream().map(o -> o.label().trim()).distinct().count();
		if (distinct != request.options().size()) {
			throw BaseException.of(ErrorCode.VALIDATION_ERROR, "options", "같은 후보가 두 번 들어 있어요.");
		}

		Poll poll = pollRepository.save(Poll.builder()
			.trip(trip)
			.creator(me)
			.title(request.title().trim())
			.slotDate(request.slotDate())
			.slotStart(request.slotStart().truncatedTo(ChronoUnit.MINUTES))
			.slotEnd(request.slotEnd().truncatedTo(ChronoUnit.MINUTES))
			.deadlineAt(request.deadlineAt())
			.build());
		for (int i = 0; i < request.options().size(); i++) {
			PollCreateRequest.OptionRequest option = request.options().get(i);
			String memo = option.memo() == null || option.memo().isBlank() ? null : option.memo().trim();
			pollOptionRepository.save(PollOption.builder().poll(poll).label(option.label().trim()).memo(memo)
				.sortOrder(i + 1).build());
		}
		eventPublisher.publishEvent(TripNotificationEvent.of(trip, me, NotificationType.POLL_CREATED,
			MemberRef.nameOf(me) + "님이 '" + poll.getTitle() + "' 투표를 열었어요", NotificationRefType.POLL,
			poll.getId()));
		return toResponses(List.of(poll), me).getFirst();
	}

	@Transactional
	public PollResponse vote(UUID tripId, UUID pollId, UUID userId, UUID optionId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Poll poll = findPoll(tripId, pollId);
		requireVotingOpen(poll);
		PollOption option = pollOptionRepository.findById(optionId)
			.filter(found -> found.getPoll().getId().equals(poll.getId()))
			.orElseThrow(() -> BaseException.of(ErrorCode.INVALID_POLL_OPTION, "optionId", "이 투표의 후보가 아니에요."));
		pollVoteRepository.findByPollIdAndMemberId(poll.getId(), me.getId()).ifPresentOrElse(
			existing -> existing.changeOption(option),
			() -> pollVoteRepository.save(PollVote.builder().poll(poll).option(option).member(me).build()));
		pollVoteRepository.flush();
		return toResponses(List.of(poll), me).getFirst();
	}

	@Transactional
	public void cancelVote(UUID tripId, UUID pollId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Poll poll = findPoll(tripId, pollId);
		requireVotingOpen(poll);
		pollVoteRepository.findByPollIdAndMemberId(poll.getId(), me.getId()).ifPresent(pollVoteRepository::delete);
	}

	@Transactional
	public PollResponse close(UUID tripId, UUID pollId, UUID userId, UUID selectedOptionId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Poll poll = findPoll(tripId, pollId);
		requireManager(poll, me);
		if (poll.getStatus() == PollStatus.CLOSED) {
			throw new BaseException(ErrorCode.POLL_CLOSED);
		}
		PollOption selected = null;
		Schedule schedule = null;
		if (selectedOptionId != null) {
			selected = pollOptionRepository.findById(selectedOptionId)
				.filter(found -> found.getPoll().getId().equals(poll.getId()))
				.orElseThrow(() -> BaseException.of(ErrorCode.INVALID_POLL_OPTION, "selectedOptionId",
					"이 투표의 후보가 아니에요."));
			schedule = scheduleService.createFromPoll(me, poll.getSlotDate(), poll.getSlotStart(), poll.getSlotEnd(),
				selected.getLabel(), "투표로 정했어요 · " + poll.getTitle());
		}
		poll.close(selected, schedule, Instant.now(clock));
		String message = "'" + poll.getTitle() + "' 투표가 마감됐어요"
			+ (selected == null ? "" : " · " + selected.getLabel() + " 일정을 추가했어요");
		eventPublisher.publishEvent(TripNotificationEvent.of(me.getTrip(), me, NotificationType.POLL_CLOSED, message,
			NotificationRefType.POLL, poll.getId()));
		pollRepository.flush();
		return toResponses(List.of(poll), me).getFirst();
	}

	// 반영된 일정은 남는다
	@Transactional
	public void deletePoll(UUID tripId, UUID pollId, UUID userId) {
		TripMember me = tripMemberGuard.requireMember(tripId, userId);
		Poll poll = findPoll(tripId, pollId);
		requireManager(poll, me);
		pollRepository.delete(poll);
	}

	private Poll findPoll(UUID tripId, UUID pollId) {
		return pollRepository.findInTrip(pollId, tripId).orElseThrow(() -> new BaseException(ErrorCode.POLL_NOT_FOUND));
	}

	private void requireVotingOpen(Poll poll) {
		if (!poll.isVotingOpen(Instant.now(clock))) {
			throw new BaseException(ErrorCode.POLL_CLOSED);
		}
	}

	private static void requireManager(Poll poll, TripMember me) {
		if (!poll.getCreator().getId().equals(me.getId()) && !me.isHost()) {
			throw new BaseException(ErrorCode.NOT_POLL_MANAGER);
		}
	}

	private List<PollResponse> toResponses(List<Poll> polls, TripMember me) {
		if (polls.isEmpty()) {
			return List.of();
		}
		List<UUID> ids = polls.stream().map(Poll::getId).toList();
		Map<UUID, List<PollOption>> options = pollOptionRepository.findByPollIdInOrderBySortOrder(ids).stream()
			.collect(Collectors.groupingBy(option -> option.getPoll().getId()));
		Map<UUID, List<PollVote>> votes = pollVoteRepository.findWithMemberByPollIds(ids).stream()
			.collect(Collectors.groupingBy(vote -> vote.getPoll().getId()));
		int memberCount = (int)tripMemberRepository.countByTripIdAndLeftAtIsNull(me.getTrip().getId());
		Instant now = Instant.now(clock);
		return polls.stream().map(poll -> {
			List<PollVote> pollVotes = votes.getOrDefault(poll.getId(), List.of());
			Map<UUID, List<PollVote>> byOption = pollVotes.stream()
				.collect(Collectors.groupingBy(vote -> vote.getOption().getId()));
			int max = byOption.values().stream().mapToInt(List::size).max().orElse(0);
			List<PollResponse.OptionResponse> optionResponses = options.getOrDefault(poll.getId(), List.of()).stream()
				.map(option -> {
					List<PollVote> optionVotes = byOption.getOrDefault(option.getId(), List.of());
					return new PollResponse.OptionResponse(option.getId(), option.getLabel(), option.getMemo(),
						option.getSortOrder(), optionVotes.size(), max > 0 && optionVotes.size() == max,
						optionVotes.stream().map(vote -> MemberRef.from(vote.getMember())).toList());
				})
				.toList();
			UUID myOptionId = pollVotes.stream()
				.filter(vote -> vote.getMember().getId().equals(me.getId()))
				.map(vote -> vote.getOption().getId())
				.findFirst()
				.orElse(null);
			boolean canManage = poll.getCreator().getId().equals(me.getId()) || me.isHost();
			return new PollResponse(poll.getId(), poll.getTitle(), poll.getSlotDate(), poll.getSlotStart(),
				poll.getSlotEnd(), poll.getDeadlineAt(), poll.getStatus(), poll.isVotingOpen(now),
				MemberRef.from(poll.getCreator()), canManage, optionResponses, pollVotes.size(), memberCount, myOptionId,
				poll.getSelectedOption() == null ? null : poll.getSelectedOption().getId(),
				poll.getSchedule() == null ? null : poll.getSchedule().getId(), poll.getCreatedAt(), poll.getClosedAt());
		}).toList();
	}
}
