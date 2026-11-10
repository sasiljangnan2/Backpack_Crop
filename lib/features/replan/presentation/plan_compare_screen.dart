import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../data/replan_models.dart';

enum CompareOutcome { applied, retry }

/// BP-AI-003 추천안 비교 · 적용. 적용 전 다른 사람이 일정을 바꾸면 다시 추천받게 한다
class PlanCompareScreen extends StatefulWidget {
  const PlanCompareScreen({
    super.key,
    required this.trip,
    required this.result,
  });

  final TripDetail trip;
  final ReplanResult result;

  @override
  State<PlanCompareScreen> createState() => _PlanCompareScreenState();
}

class _PlanCompareScreenState extends State<PlanCompareScreen> {
  late PlanKey _selected = widget.result.plans.first.key;
  bool _busy = false;

  ReplanPlan get _plan =>
      widget.result.plans.firstWhere((p) => p.key == _selected);

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      await services.replans.apply(
        widget.trip.id,
        requestId: widget.result.requestId,
        plan: _selected,
      );
      if (mounted) {
        Navigator.pop(context, CompareOutcome.applied);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.code == 'REPLAN_STALE' || e.code == 'REPLAN_EXPIRED') {
        final retry = await confirm(
          context,
          title: e.code == 'REPLAN_STALE' ? '일정이 바뀌었어요' : '추천이 만료됐어요',
          message: '${e.message}\n지금 일정은 그대로예요.',
          confirmLabel: '다시 추천받기',
        );
        if (mounted) {
          Navigator.pop(context, retry ? CompareOutcome.retry : null);
        }
        return;
      }
      showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final plan = _plan;
    final anchor = result.context.anchor;
    final empty = plan.items.isEmpty && plan.dropped.isEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('추천안 비교'),
            Text(
              '고정 일정 유지 · ${result.plans.length}안',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              result.source == ReplanSource.ai
                  ? const Pill('AI 추천', icon: Icons.auto_awesome)
                  : const Pill(
                      '기본 추천',
                      color: AppColors.muted,
                      background: AppColors.background,
                    ),
              const SizedBox(width: 8),
              if (result.notice != null)
                Expanded(
                  child: Text(
                    result.notice!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final p in result.plans) ...[
            _PlanCard(
              plan: p,
              selected: p.key == _selected,
              onTap: () => setState(() => _selected = p.key),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          const Text(
            '적용하면 남은 일정',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          AppCard(
            color: AppColors.background,
            child: Column(
              children: [
                for (final item in plan.items)
                  _PreviewRow(
                    time: Fmt.time(item.startTime),
                    title: item.title,
                    badge: const Pill('재구성'),
                  ),
                if (anchor != null)
                  _PreviewRow(
                    time: Fmt.time(anchor.startTime),
                    title: anchor.title,
                    badge: Pill(
                      anchor.isLocked ? '고정 유지' : '그대로',
                      color: Colors.white,
                      background: AppColors.ink,
                      icon: anchor.isLocked ? Icons.lock_outline : null,
                    ),
                  ),
              ],
            ),
          ),
          if (plan.dropped.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '빠지는 일정 · 적용하면 지워져요',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.error.withValues(alpha: .9),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final d in plan.dropped)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  d.title,
                  style: const TextStyle(
                    color: AppColors.muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('기존 유지'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _busy || empty ? null : _apply,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('이 안으로 적용'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final ReplanPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = plan.items.isEmpty
        ? '넣을 수 있는 일정이 없어요'
        : '${plan.items.length}곳 · ${Fmt.time(plan.startTime)}–${Fmt.time(plan.endTime)}'
              ' · 이동 ${Fmt.minutes(plan.travelMin)} · 조건 충족 ${plan.conditionRate}%';
    return Material(
      color: selected
          ? AppColors.primarySoft.withValues(alpha: .45)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 같은 안을 합치면 "이동 최소 · 시간 여유 우선"처럼 길어진다
                  Expanded(
                    child: Text(
                      plan.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  selected
                      ? const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: AppColors.primaryText,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '선택됨',
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          '선택',
                          style: TextStyle(color: AppColors.primaryText),
                        ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                summary,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (selected) ...[
                const SizedBox(height: 12),
                for (final item in plan.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            Fmt.time(item.startTime),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (item.isNew) ...[
                                    const SizedBox(width: 6),
                                    const Pill('새 장소'),
                                  ],
                                ],
                              ),
                              Text(
                                [
                                  ?item.placeText,
                                  if (item.travelBefore.minutes > 0)
                                    item.travelBefore.label,
                                  '${Fmt.minutes(item.stayMin)} 머묾',
                                ].join(' · '),
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
                if (plan.reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      plan.reason,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.time,
    required this.title,
    required this.badge,
  });

  final String time;
  final String title;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              time,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          badge,
        ],
      ),
    );
  }
}
