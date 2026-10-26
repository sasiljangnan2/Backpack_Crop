import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../../trip/presentation/trip_shell.dart';
import '../data/task_api.dart';

/// 준비 탭 (BP-PR-001): 전체 현황 · 내 담당 · 내 준비물
class PrepTab extends StatefulWidget {
  const PrepTab({super.key});

  @override
  State<PrepTab> createState() => _PrepTabState();
}

class _PrepTabState extends State<PrepTab>
    with SingleTickerProviderStateMixin, TripTabRefresh {
  late final _tabs = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));
  List<TripTask>? _tasks;
  Object? _error;
  String? _tripId;

  @override
  int get tabIndex => TripShell.prep;

  @override
  void onTabShown() => _load();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final trip = TripScope.of(context).trip;
    if (_tripId != trip.id) {
      _tripId = trip.id;
      _load();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final trip = TripScope.of(context).trip;
    try {
      final tasks = await services.tasks.tasks(trip.id);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (_tasks == null) {
        setState(() => _error = e);
      } else {
        showError(context, e);
      }
    }
  }

  /// 업무 추가 · 수정 (BP-PR-002). 저장하거나 지우면 다시 불러온다
  Future<void> _edit(TripDetail trip, {TripTask? task}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TaskEditSheet(trip: trip, task: task),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _addPrivate(TripDetail trip) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PrivateItemSheet(trip: trip),
    );
    if (added == true) {
      await _load();
    }
  }

  Future<void> _setStatus(
    TripDetail trip,
    TripTask task,
    TaskStatus status,
  ) async {
    if (task.status == status) {
      return;
    }
    try {
      await services.tasks.update(trip.id, task.id, status: status);
      await _load();
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _privateActions(TripDetail trip, TripTask task) async {
    final action = await showAppSheet<String>(
      context,
      title: task.title,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: const Text('이름 바꾸기'),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            title: const Text('삭제', style: TextStyle(color: AppColors.error)),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) {
      return;
    }
    try {
      if (action == 'rename') {
        final controller = TextEditingController(text: task.title);
        final title = await showAppSheet<String>(
          context,
          title: '이름 바꾸기',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 100,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('저장'),
              ),
            ],
          ),
        );
        if (title == null || title.isEmpty) {
          return;
        }
        await services.tasks.update(trip.id, task.id, title: title);
      } else {
        await services.tasks.delete(trip.id, task.id);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = TripScope.of(context).trip;
    final tasks = _tasks;
    final team = tasks?.where((t) => t.scope == TaskScope.team).toList() ?? [];
    final mine = team.where((t) => t.isAssignedTo(trip.myMemberId)).toList();
    final mineOpen = mine.where((t) => !t.isDone).length;
    final privateItems =
        tasks?.where((t) => t.scope == TaskScope.private).toList() ?? [];
    final onPrivate = _tabs.index == 2;
    return Scaffold(
      appBar: AppBar(
        title: const Text('준비'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            const Tab(text: '전체 현황'),
            Tab(text: mineOpen > 0 ? '내 담당 $mineOpen' : '내 담당'),
            const Tab(text: '내 준비물'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => onPrivate ? _addPrivate(trip) : _edit(trip),
        icon: const Icon(Icons.add),
        label: Text(onPrivate ? '준비물 추가' : '업무 추가'),
      ),
      body: tasks == null
          ? (_error == null
                ? const LoadingView()
                : ErrorView(error: _error!, onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: switch (_tabs.index) {
                0 => _Overview(
                  trip: trip,
                  tasks: team,
                  onOpen: (task) => _edit(trip, task: task),
                ),
                1 => _MyTasks(
                  trip: trip,
                  tasks: mine,
                  onOpen: (task) => _edit(trip, task: task),
                  onStatus: (task, status) => _setStatus(trip, task, status),
                ),
                _ => _PrivateList(
                  items: privateItems,
                  onToggle: (task) => _setStatus(
                    trip,
                    task,
                    task.isDone ? TaskStatus.todo : TaskStatus.done,
                  ),
                  onMore: (task) => _privateActions(trip, task),
                ),
              },
            ),
    );
  }
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// 상태 배지: 할 일(회색) · 진행 중(주요 색) · 완료(파랑)
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final TaskStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
    TaskStatus.todo => Pill(
      status.label,
      color: AppColors.muted,
      background: AppColors.background,
    ),
    TaskStatus.inProgress => Pill(status.label),
    TaskStatus.done => Pill(
      status.label,
      color: AppColors.success,
      background: AppColors.successSoft,
      icon: Icons.check,
    ),
  };
}

/// 마감 D-day 배지: 3일 이내는 주황, 지나면 빨강
class _DuePill extends StatelessWidget {
  const _DuePill(this.daysLeft);

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final overdue = daysLeft < 0;
    return Pill(
      overdue ? '마감 지남' : Fmt.dDay(daysLeft),
      color: overdue ? AppColors.error : AppColors.warning,
      background: overdue ? const Color(0xFFFDEEF3) : AppColors.warningSoft,
    );
  }
}

/// 전체 현황: 진행률 · 담당자별 완료 · 마감 순 목록
class _Overview extends StatelessWidget {
  const _Overview({
    required this.trip,
    required this.tasks,
    required this.onOpen,
  });

  final TripDetail trip;
  final List<TripTask> tasks;
  final void Function(TripTask task) onOpen;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: const [
          AppCard(
            child: EmptyView(
              icon: Icons.checklist_rounded,
              title: '첫 준비 업무를 추가해 보세요',
              message: '숙소 예약, 환전처럼 누가 언제까지 할지 정할 수 있어요.',
            ),
          ),
        ],
      );
    }
    final count = {
      for (final status in TaskStatus.values)
        status: tasks.where((t) => t.status == status).length,
    };
    final byMember = [
      for (final member in trip.members)
        if (tasks.any((t) => t.isAssignedTo(member.memberId)))
          (
            member,
            tasks
                .where((t) => t.isAssignedTo(member.memberId) && t.isDone)
                .length,
            tasks.where((t) => t.isAssignedTo(member.memberId)).length,
          ),
    ];
    final today = _today();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tasks.length}개 중 ${count[TaskStatus.done]}개 완료',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (trip.status == TripStatus.upcoming)
                    Text(
                      '출발 ${Fmt.dDay(trip.dDay)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _StackedProgress(
                total: tasks.length,
                done: count[TaskStatus.done]!,
                inProgress: count[TaskStatus.inProgress]!,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                children: [
                  _Legend(AppColors.success, '완료 ${count[TaskStatus.done]}'),
                  _Legend(
                    AppColors.primary,
                    '진행 중 ${count[TaskStatus.inProgress]}',
                  ),
                  _Legend(AppColors.disabled, '할 일 ${count[TaskStatus.todo]}'),
                ],
              ),
              if (byMember.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.background),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (member, done, total) in byMember)
                        Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: Column(
                            children: [
                              MemberAvatar(
                                member.name,
                                radius: 22,
                                highlight: true,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                member.isMe
                                    ? '${member.name} (나)'
                                    : member.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '$done/$total',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final (i, task) in tasks.indexed) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.background,
                  ),
                InkWell(
                  onTap: () => onOpen(task),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                    child: Row(
                      children: [
                        task.assignee == null
                            ? const CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.background,
                                child: Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: AppColors.muted,
                                ),
                              )
                            : MemberAvatar(
                                task.assignee!.name,
                                radius: 18,
                                highlight: !task.isDone,
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TaskText(
                            task: task,
                            today: today,
                            showAssignee: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(task.status),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 업무 이름(완료면 회색 + 취소선) · 담당자 · 마감일 · D-day
class _TaskText extends StatelessWidget {
  const _TaskText({
    required this.task,
    required this.today,
    required this.showAssignee,
  });

  final TripTask task;
  final DateTime today;
  final bool showAssignee;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate;
    final daysLeft = task.daysLeft(today);
    final parts = [
      if (showAssignee) task.assignee?.name ?? '담당자 없음',
      if (due != null) '${Fmt.monthDayWeek(due)} 마감',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: task.isDone ? AppColors.muted : AppColors.ink,
            decoration: task.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        if (parts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                parts.join(' · '),
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              if (!task.isDone && daysLeft != null && daysLeft <= 7)
                _DuePill(daysLeft),
            ],
          ),
        ],
      ],
    );
  }
}

class _StackedProgress extends StatelessWidget {
  const _StackedProgress({
    required this.total,
    required this.done,
    required this.inProgress,
  });

  final int total;
  final int done;
  final int inProgress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        // stretch: 빈 ColoredBox는 높이를 0으로 잡으므로 줄 높이를 채우게 한다
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (done > 0)
              Expanded(
                flex: done,
                child: const ColoredBox(color: AppColors.success),
              ),
            if (inProgress > 0)
              Expanded(
                flex: inProgress,
                child: const ColoredBox(color: AppColors.primary),
              ),
            if (total - done - inProgress > 0)
              Expanded(
                flex: total - done - inProgress,
                child: const ColoredBox(color: AppColors.background),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// 내 담당: 화면 이동 없이 진행 상태를 바로 바꾼다
class _MyTasks extends StatelessWidget {
  const _MyTasks({
    required this.trip,
    required this.tasks,
    required this.onOpen,
    required this.onStatus,
  });

  final TripDetail trip;
  final List<TripTask> tasks;
  final void Function(TripTask task) onOpen;
  final void Function(TripTask task, TaskStatus status) onStatus;

  @override
  Widget build(BuildContext context) {
    final today = _today();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (tasks.isEmpty)
          const AppCard(
            child: EmptyView(
              icon: Icons.assignment_ind_outlined,
              title: '맡은 업무가 없어요',
              message: '전체 현황에서 업무를 추가하고 담당자로 나를 고르면 여기에 모여요.',
            ),
          ),
        for (final task in tasks) ...[
          AppCard(
            onTap: () => onOpen(task),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TaskText(task: task, today: today, showAssignee: false),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final status in TaskStatus.values) ...[
                      Expanded(
                        child: ChoiceChip(
                          selected: task.status == status,
                          showCheckmark: task.status == status,
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              status.label,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onSelected: (_) => onStatus(task, status),
                        ),
                      ),
                      if (status != TaskStatus.done) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// 내 준비물: 나만 보는 체크리스트
class _PrivateList extends StatelessWidget {
  const _PrivateList({
    required this.items,
    required this.onToggle,
    required this.onMore,
  });

  final List<TripTask> items;
  final void Function(TripTask task) onToggle;
  final void Function(TripTask task) onMore;

  @override
  Widget build(BuildContext context) {
    final done = items.where((t) => t.isDone).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (items.isEmpty)
          const AppCard(
            child: EmptyView(
              icon: Icons.luggage_outlined,
              title: '챙길 준비물을 적어 보세요',
              message: '나만 보이는 체크리스트예요.',
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Text(
                  '$done/${items.length} 챙김',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: done / items.length,
                      minHeight: 5,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final item in items)
                  ListTile(
                    leading: Checkbox(
                      value: item.isDone,
                      onChanged: (_) => onToggle(item),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: item.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isDone ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: '더 보기',
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: () => onMore(item),
                    ),
                    onTap: () => onToggle(item),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 업무 등록 · 수정 (BP-PR-002) + 삭제 확인 (BP-PR-003).
/// 업무명 · 담당자 · 마감일은 필수. 처음 저장을 누른 뒤부터 빈 항목 아래에 오류를 보이고, 오류가 남으면 저장을 막는다
class _TaskEditSheet extends StatefulWidget {
  const _TaskEditSheet({required this.trip, this.task});

  final TripDetail trip;
  final TripTask? task;

  @override
  State<_TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<_TaskEditSheet> {
  late final _title = TextEditingController(text: widget.task?.title);
  late String? _assignee = widget.task?.assignee?.memberId;
  late DateTime? _due = widget.task?.dueDate;
  late TaskStatus _status = widget.task?.status ?? TaskStatus.todo;
  bool _submitted = false;
  bool _busy = false;

  bool get _editing => widget.task != null;

  String? get _titleError =>
      _submitted && _title.text.trim().isEmpty ? '업무명을 입력해 주세요.' : null;
  String? get _assigneeError =>
      _submitted && _assignee == null ? '담당자를 한 명 골라 주세요.' : null;
  String? get _dueError => _submitted && _due == null ? '마감일을 골라 주세요.' : null;
  bool get _hasError =>
      _titleError != null || _assigneeError != null || _dueError != null;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final today = _today();
    final trip = widget.trip;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _due ?? (trip.startDate.isAfter(today) ? today : trip.startDate),
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(trip.endDate.year + 1, 12, 31),
      helpText: '마감일',
    );
    if (picked != null) {
      setState(() => _due = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_hasError) {
      return;
    }
    setState(() => _busy = true);
    try {
      final task = widget.task;
      if (task == null) {
        await services.tasks.create(
          widget.trip.id,
          scope: TaskScope.team,
          title: _title.text.trim(),
          assigneeMemberId: _assignee,
          dueDate: _due,
          status: _status,
        );
      } else {
        await services.tasks.update(
          widget.trip.id,
          task.id,
          title: _title.text.trim(),
          assigneeMemberId: _assignee,
          dueDate: _due,
          status: _status,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
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

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: '이 업무를 삭제할까요?',
      message: '모든 참여자의 준비 현황에서 사라져요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await services.tasks.delete(widget.trip.id, widget.task!.id);
      if (mounted) {
        showSnack(context, '업무를 삭제했어요.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final due = _due;
    final beforeStart = due == null
        ? null
        : trip.startDate.difference(due).inDays;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? '업무 수정' : '업무 추가',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_editing)
                    IconButton(
                      tooltip: '업무 삭제',
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const FieldLabel('업무명', required: true),
              TextField(
                controller: _title,
                autofocus: !_editing,
                maxLength: 100,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '예: 엔화 환전 (¥30,000)',
                  counterText: '',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('담당자', required: true),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final member in trip.members)
                    ChoiceChip(
                      selected: _assignee == member.memberId,
                      avatar: MemberAvatar(member.name, radius: 10),
                      label: Text(
                        member.isMe ? '${member.name} (나)' : member.name,
                      ),
                      onSelected: (_) =>
                          setState(() => _assignee = member.memberId),
                    ),
                ],
              ),
              if (_assigneeError != null) _ErrorText(_assigneeError!),
              const SizedBox(height: 14),
              const FieldLabel('마감일', required: true),
              OutlinedButton.icon(
                onPressed: _pickDue,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  side: BorderSide(
                    color: _dueError == null
                        ? AppColors.border
                        : AppColors.error,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.event_outlined, size: 20),
                label: Text(
                  due == null
                      ? '날짜 선택'
                      : '${due.year}.${Fmt.monthDayWeek(due)}',
                ),
              ),
              if (_dueError != null)
                _ErrorText(_dueError!)
              else if (beforeStart != null && beforeStart > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '출발 $beforeStart일 전',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const FieldLabel('진행 상태'),
              Row(
                children: [
                  for (final status in TaskStatus.values) ...[
                    Expanded(
                      child: ChoiceChip(
                        selected: _status == status,
                        showCheckmark: _status == status,
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            status.label,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        onSelected: (_) => setState(() => _status = status),
                      ),
                    ),
                    if (status != TaskStatus.done) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy || (_submitted && _hasError) ? null : _save,
                child: Text(_editing ? '저장' : '추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.error),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

/// 내 준비물 추가 (이름만)
class _PrivateItemSheet extends StatefulWidget {
  const _PrivateItemSheet({required this.trip});

  final TripDetail trip;

  @override
  State<_PrivateItemSheet> createState() => _PrivateItemSheetState();
}

class _PrivateItemSheetState extends State<_PrivateItemSheet> {
  final _title = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await services.tasks.create(
        widget.trip.id,
        scope: TaskScope.private,
        title: _title.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '내 준비물',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  hintText: '예: 여권 챙기기',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
