import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../data/settlement_models.dart';

/// API가 돌려준 최신 공금으로 납부 현황을 갱신할 수 있게 한다.
Future<Fund?> showFundContributionSheet(
  BuildContext context, {
  required TripDetail trip,
  FundContribution? item,
  TripMember? member,
  int? suggestedKrw,
}) => showModalBottomSheet<Fund>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => _FundContributionSheet(
    trip: trip,
    item: item,
    member: member,
    suggestedKrw: suggestedKrw,
  ),
);

class _FundContributionSheet extends StatefulWidget {
  const _FundContributionSheet({
    required this.trip,
    this.item,
    this.member,
    this.suggestedKrw,
  });

  final TripDetail trip;
  final FundContribution? item;
  final TripMember? member;
  final int? suggestedKrw;

  @override
  State<_FundContributionSheet> createState() => _FundContributionSheetState();
}

class _FundContributionSheetState extends State<_FundContributionSheet> {
  late String _memberId =
      widget.member?.memberId ??
      widget.item?.member.memberId ??
      widget.trip.myMemberId;
  late final _amount = TextEditingController(
    text: (widget.item?.amountKrw ?? widget.suggestedKrw)?.toString(),
  );
  late final _memo = TextEditingController(text: widget.item?.memo);
  bool _busy = false;
  String? _amountError;

  @override
  void dispose() {
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text);
    if (amount == null || amount <= 0 || amount > 999999999999) {
      setState(() => _amountError = '1원 이상, 12자리 이내로 입력해 주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      final item = widget.item;
      final memo = _memo.text.trim().isEmpty ? null : _memo.text.trim();
      final fund = item == null
          ? await services.expenses.addFundContribution(
              widget.trip.id,
              memberId: _memberId,
              amountKrw: amount,
              memo: memo,
            )
          : await services.expenses.updateFundContribution(
              widget.trip.id,
              item.id,
              memberId: _memberId,
              amountKrw: amount,
              contributedOn: item.contributedOn,
              memo: memo,
            );
      if (mounted) {
        Navigator.pop(context, fund);
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
    setState(() => _busy = true);
    try {
      final fund = await services.expenses.deleteFundContribution(
        widget.trip.id,
        widget.item!.id,
      );
      if (mounted) {
        Navigator.pop(context, fund);
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
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.item == null ? '공금 납부 등록' : '공금 수정',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                const FieldLabel('돈을 낸 사람', required: true),
                if (widget.member case final member?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: MemberAvatar(member.name),
                    title: Text(member.name),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in widget.trip.members)
                        ChoiceChip(
                          selected: member.memberId == _memberId,
                          showCheckmark: false,
                          avatar: MemberAvatar(member.name, radius: 10),
                          label: Text(
                            member.isMe ? '${member.name} (나)' : member.name,
                          ),
                          onSelected: _busy
                              ? null
                              : (_) =>
                                    setState(() => _memberId = member.memberId),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                const FieldLabel('실제 납부액 (원)', required: true),
                TextField(
                  key: const ValueKey('fund-contribution-amount'),
                  controller: _amount,
                  onChanged: (_) {
                    if (_amountError != null) {
                      setState(() => _amountError = null);
                    }
                  },
                  enabled: !_busy,
                  autofocus: widget.item == null && widget.member == null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: InputDecoration(
                    hintText: '예: 100000',
                    errorText: _amountError,
                    prefixText: '₩ ',
                  ),
                ),
                const SizedBox(height: 14),
                const FieldLabel('메모'),
                TextField(
                  controller: _memo,
                  enabled: !_busy,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    hintText: '예: 출발 전 1차',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(widget.member == null ? '저장' : '납부 저장'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                if (widget.item != null)
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('삭제'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
