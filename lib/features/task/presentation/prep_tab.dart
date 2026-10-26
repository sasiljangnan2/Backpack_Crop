import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../../trip/presentation/trip_shell.dart';
import '../data/task_api.dart';

/// 준비 탭 (BP-PR): 함께 할 준비 · 개인 준비물
class PrepTab extends StatefulWidget {
  const PrepTab({super.key});

  @override
  State<PrepTab> createState() => _PrepTabState();
}

class _PrepTabState extends State<PrepTab> with TripTabRefresh {
  TaskScope _scope = TaskScope.team;
  final _key = GlobalKey<AsyncBuilderState<List<TripTask>>>();

  @override
  int get tabIndex => TripShell.prep;

  @override
  void onTabShown() => _key.currentState?.reload();

  Future<void> _add(TripDetail trip) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _TaskSheet(trip: trip, scope: _scope),
    );
    if (created == true) {
      await _key.currentState?.reload();
    }
  }

  Future<void> _toggle(TripDetail trip, TripTask task) async {
    try {
      await services.tasks.update(trip.id, task.id, isDone: !task.isDone);
      await _key.currentState?.reload();
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _actions(TripDetail trip, TripTask task) async {
    final action = await showAppSheet<String>(
      context,
      title: task.title,
      child: Column(
        children: [
          if (task.scope == TaskScope.team)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('담당자 바꾸기'),
              onTap: () => Navigator.pop(context, 'assign'),
            ),
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
      switch (action) {
        case 'assign':
          final picked = await _pickAssignee(trip, task.assignee?.memberId);
          if (picked == null) {
            return;
          }
          await services.tasks.update(
            trip.id,
            task.id,
            assigneeMemberId: picked.isEmpty ? null : picked,
            clearAssignee: picked.isEmpty,
          );
        case 'rename':
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
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: const Text('저장'),
                ),
              ],
            ),
          );
          if (title == null || title.isEmpty) {
            return;
          }
          await services.tasks.update(trip.id, task.id, title: title);
        case 'delete':
          await services.tasks.delete(trip.id, task.id);
      }
      await _key.currentState?.reload();
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  Future<String?> _pickAssignee(TripDetail trip, String? current) =>
      showAppSheet<String>(
        context,
        title: '담당자',
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_outline),
              title: const Text('정하지 않음'),
              trailing: current == null
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final member in trip.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MemberAvatar(member.name),
                title: Text(member.isMe ? '${member.name} (나)' : member.name),
                trailing: current == member.memberId
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, member.memberId),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final trip = TripScope.of(context).trip;
    return Scaffold(
      appBar: AppBar(
        title: const Text('준비'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<TaskScope>(
                segments: const [
                  ButtonSegment(value: TaskScope.team, label: Text('함께 준비')),
                  ButtonSegment(value: TaskScope.private, label: Text('내 준비물')),
                ],
                selected: {_scope},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _scope = value.first),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(trip),
        icon: const Icon(Icons.add),
        label: const Text('추가'),
      ),
      body: AsyncBuilder<List<TripTask>>(
        key: _key,
        load: () => services.tasks.tasks(trip.id),
        builder: (context, all, _) {
          final tasks = all.where((t) => t.scope == _scope).toList();
          final done = tasks.where((t) => t.isDone).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              if (tasks.isEmpty)
                AppCard(
                  child: EmptyView(
                    icon: _scope == TaskScope.team
                        ? Icons.groups_outlined
                        : Icons.luggage_outlined,
                    title: _scope == TaskScope.team
                        ? '함께 준비할 일을 적어 보세요'
                        : '챙길 준비물을 적어 보세요',
                    message: _scope == TaskScope.team
                        ? '숙소 예약, 환전처럼 누가 할지 정할 수 있어요.'
                        : '나만 보이는 체크리스트예요.',
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Row(
                    children: [
                      Text(
                        '$done/${tasks.length} 완료',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: done / tasks.length,
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
                      for (final task in tasks)
                        ListTile(
                          leading: Checkbox(
                            value: task.isDone,
                            onChanged: (_) => _toggle(trip, task),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isDone
                                  ? AppColors.muted
                                  : AppColors.ink,
                            ),
                          ),
                          subtitle: task.scope == TaskScope.team
                              ? Text(
                                  task.assignee == null
                                      ? '담당자 없음'
                                      : '${task.assignee!.name} 담당',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        task.assignee?.memberId ==
                                            trip.myMemberId
                                        ? AppColors.primaryText
                                        : AppColors.muted,
                                  ),
                                )
                              : null,
                          trailing: IconButton(
                            tooltip: '더 보기',
                            icon: const Icon(Icons.more_vert, size: 20),
                            onPressed: () => _actions(trip, task),
                          ),
                          onTap: () => _toggle(trip, task),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({required this.trip, required this.scope});

  final TripDetail trip;
  final TaskScope scope;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  final _title = TextEditingController();
  String? _assignee;
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
        scope: widget.scope,
        title: _title.text.trim(),
        assigneeMemberId: _assignee,
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
    final team = widget.scope == TaskScope.team;
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
              Text(
                team ? '함께 준비할 일' : '내 준비물',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  hintText: team ? '예: 숙소 예약' : '예: 여권 챙기기',
                  counterText: '',
                ),
              ),
              if (team) ...[
                const SizedBox(height: 10),
                const FieldLabel('담당자'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _assignee == null,
                      showCheckmark: false,
                      label: const Text('정하지 않음'),
                      onSelected: (_) => setState(() => _assignee = null),
                    ),
                    for (final member in widget.trip.members)
                      ChoiceChip(
                        selected: _assignee == member.memberId,
                        showCheckmark: false,
                        label: Text(member.name),
                        onSelected: (_) =>
                            setState(() => _assignee = member.memberId),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
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
