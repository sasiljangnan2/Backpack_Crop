import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../data/trip_models.dart';
import 'join_trip_screen.dart';
import 'trip_create_screen.dart';
import 'trip_shell.dart';

/// BP-CM-001 여행 전환. 여행 메인의 여행 이름을 누르면 열린다.
/// 다른 여행을 고르면 지금 여행 화면을 그 여행으로 바꾼다
Future<void> showTripSwitcher(BuildContext context, TripDetail current) async {
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TripSwitchSheet(current: current),
  );
  if (picked == null || picked == current.id || !context.mounted) {
    return;
  }
  await Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => TripShell(tripId: picked)),
  );
}

class _TripSwitchSheet extends StatelessWidget {
  const _TripSwitchSheet({required this.current});

  final TripDetail current;

  Future<void> _open(BuildContext context, Widget screen) async {
    final tripId = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => screen));
    if (tripId != null && context.mounted) {
      Navigator.pop(context, tripId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                '여행 전환',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: AsyncBuilder<List<TripSummary>>(
                refreshable: false,
                load: services.trips.myTrips,
                builder: (context, trips, _) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final trip in trips)
                      _TripRow(
                        trip: trip,
                        selected: trip.id == current.id,
                        onTap: () => Navigator.pop(context, trip.id),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: const Text('초대 코드로 참여'),
              onTap: () => _open(context, const JoinTripScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('새 여행 만들기'),
              onTap: () => _open(context, const TripCreateScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({
    required this.trip,
    required this.selected,
    required this.onTap,
  });

  final TripSummary trip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = switch (trip.status) {
      TripStatus.live => '${trip.dayNo}일차',
      TripStatus.upcoming => Fmt.dDay(trip.dDay),
      TripStatus.done => '다녀왔어요',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.coverGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${trip.destination} · ${Fmt.range(trip.startDate, trip.endDate)} · $badge',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
