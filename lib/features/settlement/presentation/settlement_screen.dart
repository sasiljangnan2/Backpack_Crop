import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../data/settlement_models.dart';

/// BP-ST-001 최종 정산 · 송금 경로 (경비 탭의 "정산")
class SettlementView extends StatefulWidget {
  const SettlementView({super.key, required this.trip});

  final TripDetail trip;

  @override
  State<SettlementView> createState() => _SettlementViewState();
}

class _SettlementViewState extends State<SettlementView> {
  final _key =
      GlobalKey<
        AsyncBuilderState<(Settlement, List<SettlementShareSummary>)>
      >();

  Future<(Settlement, List<SettlementShareSummary>)> _load() async {
    final results = await Future.wait<Object>([
      services.expenses.settlement(widget.trip.id),
      services.expenses.shares(widget.trip.id),
    ]);
    return (
      results[0] as Settlement,
      results[1] as List<SettlementShareSummary>,
    );
  }

  /// 공유 시트 (BP-ST-003): 이미지로 공유 · 텍스트로 복사 · 멤버에게 알리기
  Future<void> _share(Settlement settlement) async {
    final notified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ShareSheet(trip: widget.trip, settlement: settlement),
    );
    if (notified == true) {
      await _key.currentState?.reload();
    }
  }

  void _showReason(Settlement settlement, Transfer transfer) {
    SettlementMember? find(String id) {
      for (final m in settlement.members) {
        if (m.memberId == id) {
          return m;
        }
      }
      return null;
    }

    final from = find(transfer.from.memberId);
    final to = find(transfer.to.memberId);
    final mineInvolved = from?.isMe == true || to?.isMe == true;
    showAppSheet<void>(
      context,
      title:
          '${transfer.from.name} → ${transfer.to.name} ${Fmt.krw(transfer.amountKrw)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '각자 낸 돈에서 부담할 돈을 빼면 잔액이 나와요. 보낼 돈이 있는 사람과 받을 돈이 있는 사람을 이어 송금 건수를 줄였어요.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          for (final member in [from, to])
            if (member != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  color: AppColors.background,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.isMe ? '${member.name} (나)' : member.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '낸 돈 ${Fmt.krw(member.paidKrw)} − 부담할 돈 ${Fmt.krw(member.shareKrw)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        '= ${Fmt.signedKrw(member.balanceKrw)} (${member.balanceKrw >= 0 ? '받을 돈' : '보낼 돈'})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: member.balanceKrw >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (mineInvolved)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MySettlementScreen(trip: widget.trip),
                  ),
                );
              },
              child: const Text('내 지출별 계산 근거 보기 ›'),
            ),
          const Text(
            '실제 송금은 각자 쓰는 은행 · 송금 앱에서 해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return AsyncBuilder<(Settlement, List<SettlementShareSummary>)>(
      key: _key,
      load: _load,
      builder: (context, data, _) {
        final (settlement, shares) = data;
        final memberCount = settlement.members.where((m) => !m.hasLeft).length;
        final reduced =
            settlement.directTransferCount > settlement.transfers.length &&
            settlement.transfers.isNotEmpty;
        if (settlement.expenseCount == 0) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: const [
              AppCard(
                child: EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: '정산할 지출이 아직 없어요',
                  message: '지출을 등록하면 누가 누구에게 얼마를 보낼지 바로 계산해요.',
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '최종 정산 · 지출 ${settlement.expenseCount}건 · $memberCount명',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '정산 결과 공유',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _share(settlement),
                        icon: const Icon(Icons.share_outlined, size: 22),
                      ),
                    ],
                  ),
                  Text(
                    Fmt.krw(settlement.totalKrw),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (reduced)
                        Pill(
                          '송금 ${settlement.directTransferCount}건 → ${settlement.transfers.length}건으로 줄였어요',
                          icon: Icons.alt_route,
                        ),
                      if (memberCount > 0)
                        Text(
                          '1인 평균 ${Fmt.krw((settlement.totalKrw / memberCount).round())}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MySettlementScreen(trip: trip),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('내 계산 근거 보기'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          '개인별 잔액',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '받을 돈',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      Text(
                        '보낼 돈',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _BalanceBars(members: settlement.members),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: settlement.transfers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '모두 낸 만큼 썼어요. 주고받을 돈이 없어요.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이렇게 보내면 끝나요 · ${settlement.transfers.length}건',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final (i, transfer)
                            in settlement.transfers.indexed) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color: AppColors.background,
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                MemberAvatar(
                                  transfer.from.name,
                                  radius: 18,
                                  highlight: true,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    size: 18,
                                    color: AppColors.muted,
                                  ),
                                ),
                                MemberAvatar(
                                  transfer.to.name,
                                  radius: 18,
                                  highlight: true,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${transfer.from.name} → ${transfer.to.name}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      Text(
                                        Fmt.krw(transfer.amountKrw),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: () =>
                                      _showReason(settlement, transfer),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 38),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    backgroundColor: AppColors.primarySoft,
                                    foregroundColor: AppColors.primaryText,
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('근거'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: settlement.transfers.isEmpty
                  ? null
                  : () => _share(settlement),
              icon: const Icon(Icons.share_outlined),
              label: const Text('정산 결과 공유'),
            ),
            if (shares.isNotEmpty) ...[
              const SectionTitle('공유 기록'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final share in shares)
                      ListTile(
                        title: Text(
                          '${share.sharedBy.name}님 · 송금 ${share.transferCount}건',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${Fmt.krw(share.transferTotalKrw)} · ${Fmt.ago(share.createdAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SettlementShareScreen(
                              trip: trip,
                              shareId: share.id,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 개인별 잔액 막대 (스토리보드 BC-004 ⑥): 가운데 기준선에서 오른쪽 = 받을 돈, 왼쪽 = 보낼 돈
class _BalanceBars extends StatelessWidget {
  const _BalanceBars({required this.members});

  final List<SettlementMember> members;

  @override
  Widget build(BuildContext context) {
    final maxAbs = members.fold<int>(
      1,
      (max, m) => m.balanceKrw.abs() > max ? m.balanceKrw.abs() : max,
    );
    return Column(
      children: [
        for (final member in members)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                MemberAvatar(member.name, radius: 16, highlight: member.isMe),
                const SizedBox(width: 10),
                // 나는 진한 아바타로 구분하고, 이름 칸은 막대 자리를 남기고 넉넉히
                SizedBox(
                  width: 84,
                  child: Text(
                    '${member.name}${member.hasLeft ? ' · 나감' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 22,
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: member.balanceKrw < 0
                                ? _Bar(
                                    fraction: member.balanceKrw.abs() / maxAbs,
                                    color: AppColors.error,
                                    left: true,
                                  )
                                : null,
                          ),
                        ),
                        Container(width: 2, color: AppColors.border),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: member.balanceKrw > 0
                                ? _Bar(
                                    fraction: member.balanceKrw / maxAbs,
                                    color: AppColors.success,
                                    left: false,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: Text(
                    member.balanceKrw == 0
                        ? '정산 완료'
                        : Fmt.signedKrw(member.balanceKrw),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: member.balanceKrw > 0
                          ? AppColors.success
                          : member.balanceKrw < 0
                          ? AppColors.error
                          : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color, required this.left});

  final double fraction;
  final Color color;
  final bool left;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(11);
    return FractionallySizedBox(
      widthFactor: fraction.clamp(.06, 1).toDouble(),
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: left
              ? const BorderRadius.horizontal(left: radius)
              : const BorderRadius.horizontal(right: radius),
        ),
      ),
    );
  }
}

/// 정산 결과 공유 (BP-ST-003)
class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.trip, required this.settlement});

  final TripDetail trip;
  final Settlement settlement;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _card = GlobalKey();
  bool _busy = false;

  String get _text {
    final s = widget.settlement;
    final now = DateTime.now();
    return [
      '[${widget.trip.name}] 정산 결과 (${Fmt.monthDayWeek(now)} 기준)',
      '총 지출 ${Fmt.krw(s.totalKrw)} · 지출 ${s.expenseCount}건',
      '',
      for (final t in s.transfers)
        '${t.from.name} → ${t.to.name} ${Fmt.krw(t.amountKrw)}',
      '',
      'Backpack에서 계산했어요',
    ].join('\n');
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes!.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'backpack_settlement.png',
            ),
          ],
          fileNameOverrides: const ['backpack_settlement.png'],
          text: '${widget.trip.name} 정산 결과',
        ),
      );
    } catch (_) {
      if (mounted) {
        showSnack(context, '이미지를 만들지 못했어요. 텍스트로 복사해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (mounted) {
      showSnack(context, '송금 목록을 복사했어요.');
    }
  }

  Future<void> _notifyMembers() async {
    setState(() => _busy = true);
    try {
      await services.expenses.share(widget.trip.id);
      if (mounted) {
        showSnack(context, '멤버들에게 정산 결과를 알렸어요.');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(
          context,
          e.code == 'NOTHING_TO_SETTLE' ? '주고받을 돈이 없어요.' : e.displayMessage,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '정산 결과 공유',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            RepaintBoundary(
              key: _card,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.coverGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.trip.name} · 정산 결과',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        shadows: AppColors.coverShadow,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '총 지출 ${Fmt.krw(s.totalKrw)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        shadows: AppColors.coverShadow,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '송금 ${s.transfers.length}건',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                          for (final t in s.transfers)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${t.from.name} → ${t.to.name}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    Fmt.krw(t.amountKrw),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${Fmt.monthDayWeek(DateTime.now())} 기준 · Backpack',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        shadows: AppColors.coverShadow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _shareImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('이미지로 공유'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _copyText,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('텍스트로 복사'),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _busy ? null : _notifyMembers,
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('앱에서 멤버들에게 알리기'),
            ),
          ],
        ),
      ),
    );
  }
}

/// BP-ST-002 계산 근거 (내 정산)
class MySettlementScreen extends StatelessWidget {
  const MySettlementScreen({super.key, required this.trip});

  final TripDetail trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계산 근거')),
      body: AsyncBuilder<MySettlement>(
        load: () => services.expenses.mySettlement(trip.id),
        builder: (context, mine, _) {
          final (label, color) = switch (mine.status) {
            SettlementStatus.receive => ('받을 돈', AppColors.success),
            SettlementStatus.send => ('보낼 돈', AppColors.error),
            SettlementStatus.settled => ('정산할 돈 없음', AppColors.muted),
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '지금까지 내 정산 · $label',
                      style: TextStyle(color: color, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Fmt.krw(mine.balanceKrw.abs()),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Line('내가 낸 돈', Fmt.krw(mine.paidKrw)),
                    _Line('내가 부담할 돈', Fmt.krw(mine.shareKrw)),
                    const Divider(height: 18),
                    _Line(
                      '잔액 (낸 돈 − 부담할 돈)',
                      Fmt.signedKrw(mine.balanceKrw),
                      bold: true,
                    ),
                  ],
                ),
              ),
              if (mine.transfers.isNotEmpty) ...[
                const SectionTitle('내 송금'),
                AppCard(
                  child: Column(
                    children: [
                      for (final transfer in mine.transfers)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                transfer.direction == TransferDirection.send
                                    ? Icons.north_east
                                    : Icons.south_west,
                                color:
                                    transfer.direction == TransferDirection.send
                                    ? AppColors.error
                                    : AppColors.success,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  transfer.direction == TransferDirection.send
                                      ? '${transfer.counterpart.name}님에게 보내기'
                                      : '${transfer.counterpart.name}님에게 받기',
                                ),
                              ),
                              Text(
                                Fmt.krw(transfer.amountKrw),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SectionTitle('지출별 내역 · ${mine.expenses.length}건'),
              if (mine.expenses.isEmpty)
                const AppCard(
                  child: Text(
                    '나와 관련된 지출이 없어요.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final line in mine.expenses)
                        ListTile(
                          leading: Icon(
                            line.category.icon,
                            color: line.category.color,
                          ),
                          title: Text(
                            line.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${Fmt.monthDay(line.paidDate)} · ${Fmt.krw(line.amountKrw)} · '
                            '${line.isPaidByMe ? '내가 결제' : '${line.payer.name}님 결제'}\n'
                            '내 몫 ${Fmt.krw(line.myShareKrw)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            Fmt.signedKrw(line.balanceKrw),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: line.balanceKrw > 0
                                  ? AppColors.success
                                  : line.balanceKrw < 0
                                  ? AppColors.error
                                  : AppColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style.copyWith(
                color: bold ? AppColors.ink : AppColors.muted,
              ),
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// BP-ST-003 공유한 정산
class SettlementShareScreen extends StatelessWidget {
  const SettlementShareScreen({
    super.key,
    required this.trip,
    required this.shareId,
  });

  final TripDetail trip;
  final String shareId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공유한 정산')),
      body: AsyncBuilder<SettlementShare>(
        load: () => services.expenses.shareDetail(trip.id, shareId),
        builder: (context, share, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${share.sharedBy.name}님이 ${Fmt.shortDate(share.createdAt.toLocal())} 공유',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '송금 ${share.transfers.length}건 · ${Fmt.krw(share.transferTotalKrw)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '공유한 시점의 목록이에요. 이후 지출이 바뀌면 정산 탭의 값이 달라질 수 있어요.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  for (final transfer in share.transfers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${transfer.from.name} → ${transfer.to.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            Fmt.krw(transfer.amountKrw),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
