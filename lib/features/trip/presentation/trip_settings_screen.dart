import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../data/trip_models.dart';
import 'invite_sheet.dart';
import 'trip_create_screen.dart';
import 'trip_shell.dart';

/// 여행 설정: 멤버 · 초대 · 내 선불 환율 · 여행 수정(방장) · 나가기 · 삭제(방장)
class TripSettingsScreen extends StatefulWidget {
  const TripSettingsScreen({super.key, required this.scope});

  final TripScope scope;

  @override
  State<TripSettingsScreen> createState() => _TripSettingsScreenState();
}

class _TripSettingsScreenState extends State<TripSettingsScreen> {
  late TripDetail _trip = widget.scope.trip;

  Future<void> _reload() async {
    await widget.scope.reload();
    final trip = await services.trips.trip(_trip.id);
    if (mounted) {
      setState(() => _trip = trip);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => TripCreateScreen(initial: _trip)),
    );
    if (changed != null) {
      await _reload();
    }
  }

  Future<void> _editPrepaidRate() async {
    final controller = TextEditingController(
      text: _trip.me.prepaidRate == null
          ? ''
          : Fmt.number(_trip.me.prepaidRate!),
    );
    final result = await showAppSheet<double?>(
      context,
      title: '내 선불 환율',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '여행 전에 환전한 환율을 넣어 두면, 지출을 "내 환전 환율"로 계산할 수 있어요.\n'
            '1${_trip.currencyCode}당 원화 금액을 입력해 주세요.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              hintText: _trip.currencyCode == 'JPY' ? '예: 9.12' : '예: 1382.5',
              suffixText: '원 / 1${_trip.currencyCode}',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, -1.0),
                  child: const Text('해제'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text);
                    if (value != null && value > 0) {
                      Navigator.pop(context, value);
                    }
                  },
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      await services.trips.changePrepaidRate(
        _trip.id,
        result < 0 ? null : result,
      );
      await _reload();
      if (mounted) {
        showSnack(context, result < 0 ? '선불 환율을 해제했어요.' : '선불 환율을 저장했어요.');
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _leave() async {
    final ok = await confirm(
      context,
      title: '여행에서 나갈까요?',
      message: _trip.isHost
          ? '방장은 가장 먼저 참여한 멤버에게 넘어가요. 내가 기록한 지출과 정산은 여행에 남아요.'
          : '내가 기록한 지출과 정산은 여행에 남아요. 초대 코드로 다시 들어올 수 있어요.',
      confirmLabel: '나가기',
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await services.trips.leave(_trip.id);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: '여행을 삭제할까요?',
      message: '일정, 지출, 정산, 준비 목록이 모두 지워지고 되돌릴 수 없어요. 멤버들에게도 알림이 가요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await services.trips.delete(_trip.id);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        showSnack(context, '여행을 삭제했어요.');
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    return Scaffold(
      appBar: AppBar(title: const Text('여행 설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${trip.destination} · ${Fmt.range(trip.startDate, trip.endDate)} · '
                  '${trip.currencyCode}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                if (trip.isHost) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _edit,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('여행 정보 수정'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionTitle(
            '멤버 ${trip.members.length}명',
            trailing: TextButton.icon(
              onPressed: () => showInviteSheet(context, trip),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('초대'),
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final member in trip.members)
                  ListTile(
                    leading: MemberAvatar(member.name, highlight: member.isMe),
                    title: Text(
                      member.isMe ? '${member.name} (나)' : member.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: member.prepaidRate == null
                        ? null
                        : Text('선불 환율 ${Fmt.number(member.prepaidRate!)}원'),
                    trailing: member.role == MemberRole.host
                        ? const Pill('방장')
                        : null,
                  ),
              ],
            ),
          ),
          if (!trip.isKrwTrip) ...[
            const SizedBox(height: 12),
            AppCard(
              onTap: _editPrepaidRate,
              child: Row(
                children: [
                  const Icon(Icons.currency_exchange, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '내 선불 환율',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          trip.me.prepaidRate == null
                              ? '환전해 간 환율로 지출을 계산할 때 써요'
                              : '1${trip.currencyCode} = ${Fmt.number(trip.me.prepaidRate!)}원',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextButton(
            onPressed: _leave,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('여행 나가기'),
          ),
          if (trip.isHost)
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              child: const Text('여행 삭제'),
            ),
        ],
      ),
    );
  }
}
