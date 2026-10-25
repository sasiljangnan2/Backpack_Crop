import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../data/schedule_models.dart';
import 'schedule_sheets.dart';

/// BP-VT-001 장소 투표 목록
class PollListScreen extends StatefulWidget {
  const PollListScreen({super.key, required this.trip});

  final TripDetail trip;

  @override
  State<PollListScreen> createState() => _PollListScreenState();
}

class _PollListScreenState extends State<PollListScreen> {
  final _list = GlobalKey<AsyncBuilderState<List<Poll>>>();

  Future<void> _open(Poll poll) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PollDetailScreen(trip: widget.trip, pollId: poll.id),
      ),
    );
    _list.currentState?.reload();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Poll>(
      MaterialPageRoute(builder: (_) => PollCreateScreen(trip: widget.trip)),
    );
    _list.currentState?.reload();
    if (created != null && mounted) {
      await _open(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('장소 투표')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('투표 만들기'),
      ),
      body: AsyncBuilder<List<Poll>>(
        key: _list,
        load: () => services.schedules.polls(widget.trip.id),
        builder: (context, polls, _) {
          if (polls.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 40),
                EmptyView(
                  icon: Icons.how_to_vote_outlined,
                  title: '진행 중인 투표가 없어요',
                  message: '어디 갈지 고민될 때 후보를 올리고\n함께 투표해 보세요.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              for (final poll in polls) ...[
                _PollCard(poll: poll, onTap: () => _open(poll)),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll, required this.onTap});

  final Poll poll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final leading = poll.options
        .where((o) => o.isLeading)
        .map((o) => o.label)
        .join(', ');
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (poll.isVotingOpen)
                const Pill('투표 중')
              else
                const Pill(
                  '마감',
                  color: AppColors.muted,
                  background: AppColors.background,
                ),
              const SizedBox(width: 8),
              if (poll.myOptionId != null && poll.isVotingOpen)
                const Pill(
                  '투표함',
                  color: AppColors.success,
                  background: AppColors.successSoft,
                ),
              const Spacer(),
              Text(
                '${poll.voteCount}/${poll.memberCount}명 참여',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            poll.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${Fmt.shortDate(poll.slotDate)} ${Fmt.time(poll.slotStart)}–${Fmt.time(poll.slotEnd)}'
            '${poll.selectedOption != null
                ? ' · ${poll.selectedOption!.label}로 정했어요'
                : leading.isEmpty
                ? ''
                : ' · 1위 $leading'}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// BP-VT-002 투표 만들기
class PollCreateScreen extends StatefulWidget {
  const PollCreateScreen({super.key, required this.trip});

  final TripDetail trip;

  @override
  State<PollCreateScreen> createState() => _PollCreateScreenState();
}

class _PollCreateScreenState extends State<PollCreateScreen> {
  final _title = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  final _memos = [TextEditingController(), TextEditingController()];
  late DateTime _day = widget.trip.dates.first;
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 30);
  TimeOfDay _end = const TimeOfDay(hour: 20, minute: 0);
  DateTime? _deadline;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    for (final c in [..._options, ..._memos]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ready =>
      _title.text.trim().isNotEmpty &&
      _options.where((c) => c.text.trim().isNotEmpty).length >= 2 &&
      minutesOf(_end) > minutesOf(_start) &&
      !_busy;

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: widget.trip.endDate.add(const Duration(days: 1)),
      initialDate: now,
      helpText: '마감 날짜',
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await pickTime(
      context,
      const TimeOfDay(hour: 21, minute: 0),
      '마감 시간',
    );
    if (time == null) {
      return;
    }
    setState(
      () => _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final options = <({String label, String? memo})>[
        for (int i = 0; i < _options.length; i++)
          if (_options[i].text.trim().isNotEmpty)
            (
              label: _options[i].text.trim(),
              memo: _memos[i].text.trim().isEmpty
                  ? null
                  : _memos[i].text.trim(),
            ),
      ];
      final poll = await services.schedules.createPoll(
        widget.trip.id,
        title: _title.text.trim(),
        slotDate: _day,
        slotStart: _start,
        slotEnd: _end,
        deadlineAt: _deadline,
        options: options,
      );
      if (mounted) {
        Navigator.pop(context, poll);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('투표 만들기'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const FieldLabel('무엇을 정할까요?', required: true),
          TextField(
            controller: _title,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: '예: 둘째 날 저녁 어디서 먹을까요?',
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const FieldLabel('정해지면 넣을 일정 시간', required: true),
          DropdownButtonFormField<DateTime>(
            initialValue: _day,
            items: [
              for (final date in trip.dates)
                DropdownMenuItem(
                  value: date,
                  child: Text(
                    'DAY ${trip.dayNumberOf(date)} · ${Fmt.shortDate(date)}',
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _day = value ?? _day),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await pickTime(context, _start, '시작');
                    if (picked != null) {
                      setState(() => _start = picked);
                    }
                  },
                  child: Text('시작 ${Fmt.time(_start)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await pickTime(context, _end, '종료');
                    if (picked != null) {
                      setState(() => _end = picked);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: minutesOf(_end) > minutesOf(_start)
                        ? AppColors.ink
                        : AppColors.error,
                  ),
                  child: Text('종료 ${Fmt.time(_end)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('후보 (2~6개)', required: true),
          for (int i = 0; i < _options.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _options[i],
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: '후보 ${i + 1}',
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_options.length > 2)
                  IconButton(
                    tooltip: '후보 빼기',
                    onPressed: () => setState(() {
                      _options.removeAt(i).dispose();
                      _memos.removeAt(i).dispose();
                    }),
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _memos[i],
              maxLength: 255,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: '메모 (도보·대기·비용 등, 선택)',
                counterText: '',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_options.length < 6)
            TextButton.icon(
              onPressed: () => setState(() {
                _options.add(TextEditingController());
                _memos.add(TextEditingController());
              }),
              icon: const Icon(Icons.add),
              label: const Text('후보 추가'),
            ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.timer_outlined),
            title: Text(
              _deadline == null
                  ? '마감 시간 없음'
                  : '${Fmt.shortDate(_deadline!)} ${Fmt.time(TimeOfDay.fromDateTime(_deadline!))}까지',
            ),
            trailing: _deadline == null
                ? TextButton(onPressed: _pickDeadline, child: const Text('정하기'))
                : IconButton(
                    tooltip: '마감 시간 지우기',
                    onPressed: () => setState(() => _deadline = null),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: _ready ? _submit : null,
          child: const Text('투표 열기'),
        ),
      ),
    );
  }
}

/// BP-VT-003 · 004 투표하기 · 마감
class PollDetailScreen extends StatefulWidget {
  const PollDetailScreen({super.key, required this.trip, required this.pollId});

  final TripDetail trip;
  final String pollId;

  @override
  State<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends State<PollDetailScreen> {
  Poll? _poll;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final poll = await services.schedules.poll(widget.trip.id, widget.pollId);
      if (mounted) {
        setState(() {
          _poll = poll;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _run(Future<Poll?> Function() action) async {
    setState(() => _busy = true);
    try {
      final poll = await action();
      if (mounted && poll != null) {
        setState(() => _poll = poll);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(
          context,
          e.code == 'SCHEDULE_OVERLAP'
              ? "그 시간에 '${e.details['title']}' 일정이 있어요. 일정을 먼저 옮겨 주세요."
              : e.displayMessage,
        );
      }
      await _load();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _vote(PollOption option) => _run(() async {
    final poll = _poll!;
    if (poll.myOptionId == option.id) {
      await services.schedules.cancelVote(widget.trip.id, poll.id);
      return services.schedules.poll(widget.trip.id, poll.id);
    }
    return services.schedules.vote(widget.trip.id, poll.id, option.id);
  });

  Future<void> _close() async {
    final poll = _poll!;
    final selected = await showAppSheet<String>(
      context,
      title: '투표 마감',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '고른 후보로 ${Fmt.shortDate(poll.slotDate)} ${Fmt.time(poll.slotStart)}–${Fmt.time(poll.slotEnd)} 일정을 만들어요.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final option in poll.options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: option.isLeading
                  ? const Icon(
                      Icons.emoji_events_outlined,
                      color: AppColors.primary,
                    )
                  : const Icon(Icons.place_outlined),
              title: Text(
                option.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${option.voteCount}표'),
              onTap: () => Navigator.pop(context, option.id),
            ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('일정 없이 마감만 하기'),
          ),
        ],
      ),
    );
    if (selected == null) {
      return;
    }
    await _run(
      () => services.schedules.closePoll(
        widget.trip.id,
        poll.id,
        selectedOptionId: selected.isEmpty ? null : selected,
      ),
    );
    if (mounted && selected.isNotEmpty && _poll?.scheduleId != null) {
      showSnack(context, '일정에 추가했어요.');
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: '투표를 삭제할까요?',
      message: '이미 일정에 넣은 장소는 남아요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    try {
      await services.schedules.deletePoll(widget.trip.id, widget.pollId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = _poll;
    return Scaffold(
      appBar: AppBar(
        title: const Text('투표'),
        actions: [
          if (poll?.canManage ?? false)
            IconButton(
              tooltip: '투표 삭제',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: poll == null
          ? (_error == null
                ? const LoadingView()
                : ErrorView(error: _error!, onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${Fmt.shortDate(poll.slotDate)} ${Fmt.time(poll.slotStart)}–${Fmt.time(poll.slotEnd)}'
                          ' · ${poll.creator.name}님이 열었어요',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        if (poll.deadlineAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${Fmt.shortDate(poll.deadlineAt!.toLocal())} '
                            '${Fmt.time(TimeOfDay.fromDateTime(poll.deadlineAt!.toLocal()))} 마감',
                            style: TextStyle(
                              fontSize: 12,
                              color: poll.isVotingOpen
                                  ? AppColors.warning
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${poll.voteCount}/${poll.memberCount}명 참여'
                          '${poll.isVotingOpen ? ' · 후보를 누르면 투표돼요 (다시 누르면 취소)' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final option in poll.options) ...[
                    _OptionCard(
                      option: option,
                      total: poll.voteCount,
                      mine: poll.myOptionId == option.id,
                      selected: poll.selectedOptionId == option.id,
                      onTap: poll.isVotingOpen && !_busy
                          ? () => _vote(option)
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!poll.isVotingOpen && poll.selectedOption != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "'${poll.selectedOption!.label}'로 정하고 일정에 넣었어요.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar:
          poll != null && poll.canManage && poll.status == PollStatus.open
          ? BottomActionBar(
              child: FilledButton(
                onPressed: _busy ? null : _close,
                child: const Text('마감하고 일정에 넣기'),
              ),
            )
          : null,
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.total,
    required this.mine,
    required this.selected,
    required this.onTap,
  });

  final PollOption option;
  final int total;
  final bool mine;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : option.voteCount / total;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: mine || selected ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    mine ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: mine ? AppColors.primary : AppColors.border,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    const Pill(
                      '선택됨',
                      color: AppColors.success,
                      background: AppColors.successSoft,
                    )
                  else if (option.isLeading)
                    const Pill('1위'),
                  const SizedBox(width: 8),
                  Text(
                    '${option.voteCount}표',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (option.memo != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    option.memo!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: AppColors.background,
                ),
              ),
              if (option.voters.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  option.voters.map((v) => v.name).join(', '),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
