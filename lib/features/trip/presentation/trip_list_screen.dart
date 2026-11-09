import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../notification/presentation/notification_bell.dart';
import '../../user/presentation/profile_screen.dart';
import '../data/trip_models.dart';
import 'join_trip_screen.dart';
import 'trip_create_screen.dart';
import 'trip_shell.dart';

/// BP-TR-001 내 여행 목록
class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  final _list = GlobalKey<AsyncBuilderState<List<TripSummary>>>();

  Future<void> _open(BuildContext context, String tripId) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => TripShell(tripId: tripId)));
    _list.currentState?.reload();
  }

  Future<void> _create(BuildContext context) async {
    final tripId = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const TripCreateScreen()));
    _list.currentState?.reload();
    if (tripId != null && context.mounted) {
      await _open(context, tripId);
    }
  }

  Future<void> _join(BuildContext context) async {
    final tripId = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const JoinTripScreen()));
    _list.currentState?.reload();
    if (tripId != null && context.mounted) {
      await _open(context, tripId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = services.auth.user?.name;
    return Scaffold(
      appBar: AppBar(
        title: Text(name == null ? '내 여행' : '$name님의 여행'),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: '내 정보',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncBuilder<List<TripSummary>>(
        key: _list,
        load: services.trips.myTrips,
        builder: (context, trips, reload) {
          if (trips.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 40),
                EmptyView(
                  icon: Icons.luggage_outlined,
                  title: '아직 여행이 없어요',
                  // 만들기·참여 버튼은 아래 고정 버튼으로 둔다
                  message: '아래 버튼으로 여행을 만들고 친구에게 초대 코드를 보내 보세요.\n초대 코드를 받았다면 바로 참여할 수 있어요.',
                ),
              ],
            );
          }
          final groups = <(String, List<TripSummary>)>[
            ('여행 중', trips.where((t) => t.status == TripStatus.live).toList()),
            (
              '다가오는 여행',
              trips.where((t) => t.status == TripStatus.upcoming).toList(),
            ),
            ('지난 여행', trips.where((t) => t.status == TripStatus.done).toList()),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            children: [
              for (final (title, items) in groups)
                if (items.isNotEmpty) ...[
                  SectionTitle(title),
                  for (final trip in items) ...[
                    _TripCard(trip: trip, onTap: () => _open(context, trip.id)),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
      bottomNavigationBar: BottomActionBar(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _join(context),
                icon: const Icon(Icons.confirmation_number_outlined, size: 20),
                label: const Text('코드로 참여'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('여행 만들기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final TripSummary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (trip.status) {
      TripStatus.live => (
        '${trip.dayNo}일차',
        AppColors.primaryText,
        AppColors.primarySoft,
      ),
      TripStatus.upcoming => (
        Fmt.dDay(trip.dDay),
        AppColors.ink,
        AppColors.background,
      ),
      TripStatus.done => ('다녀왔어요', AppColors.muted, AppColors.background),
    };
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: trip.status == TripStatus.done
                  ? null
                  : AppColors.coverGradient,
              color: trip.status == TripStatus.done
                  ? AppColors.background
                  : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.flight_takeoff_rounded,
              color: trip.status == TripStatus.done
                  ? AppColors.muted
                  : Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${trip.destination} · ${trip.currencyCode} · ${Fmt.range(trip.startDate, trip.endDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trip.memberCount}명${trip.myRole == MemberRole.host ? ' · 방장' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Pill(label, color: color, background: background),
        ],
      ),
    );
  }
}
