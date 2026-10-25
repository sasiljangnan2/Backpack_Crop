import 'package:flutter/material.dart';

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

  Future<void> _share() async {
    final ok = await confirm(
      context,
      title: '정산 결과를 공유할까요?',
      message: '지금의 송금 목록을 저장하고 멤버들에게 알려요.',
      confirmLabel: '공유',
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await services.expenses.share(widget.trip.id);
      if (mounted) {
        showSnack(context, '정산 결과를 공유했어요.');
      }
      await _key.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(
          context,
          e.code == 'NOTHING_TO_SETTLE' ? '주고받을 돈이 없어요.' : e.displayMessage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return AsyncBuilder<(Settlement, List<SettlementShareSummary>)>(
      key: _key,
      load: _load,
      builder: (context, data, _) {
        final (settlement, shares) = data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '전체 지출 · ${settlement.expenseCount}건',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Fmt.krw(settlement.totalKrw),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
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
            const SectionTitle('사람별 잔액'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final member in settlement.members)
                    ListTile(
                      leading: MemberAvatar(
                        member.name,
                        highlight: member.isMe,
                      ),
                      title: Text(
                        '${member.name}${member.isMe ? ' (나)' : ''}${member.hasLeft ? ' · 나감' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '낸 돈 ${Fmt.krw(member.paidKrw)} · 부담 ${Fmt.krw(member.shareKrw)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: _Balance(member.balanceKrw, member.status),
                    ),
                ],
              ),
            ),
            const SectionTitle('송금 경로 · 최소 건수'),
            AppCard(
              child: settlement.transfers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '주고받을 돈이 없어요.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : Column(
                      children: [
                        for (final transfer in settlement.transfers)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                MemberAvatar(transfer.from.name, radius: 14),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    transfer.from.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: AppColors.muted,
                                  ),
                                ),
                                MemberAvatar(transfer.to.name, radius: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    transfer.to.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '송금 합계',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              Fmt.krw(settlement.transferTotalKrw),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: settlement.transfers.isEmpty ? null : _share,
              icon: const Icon(Icons.campaign_outlined),
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

class _Balance extends StatelessWidget {
  const _Balance(this.balance, this.status);

  final int balance;
  final SettlementStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SettlementStatus.receive => ('받을 돈', AppColors.success),
      SettlementStatus.send => ('보낼 돈', AppColors.error),
      SettlementStatus.settled => ('정산 완료', AppColors.muted),
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          Fmt.krw(balance.abs()),
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
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
                            color: AppColors.primary,
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
