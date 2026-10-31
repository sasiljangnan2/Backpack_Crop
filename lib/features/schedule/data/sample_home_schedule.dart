import '../../trip/data/trip_repository.dart';
import 'memory_schedule_repository.dart';
import 'schedule_models.dart';
import 'schedule_repository.dart';

/// The storyboard home owns a separate, session-only schedule preview.
class SampleHomeSchedule {
  SampleHomeSchedule()
    : trip = TripDetail(
        id: 'sample-home-osaka',
        name: '오사카 4박 5일',
        destination: '일본 오사카',
        startDate: '2026-10-02',
        endDate: '2026-10-06',
        currencyCode: 'JPY',
        inviteCode: 'OSAKA26',
        myMemberId: 'sample-home-member-self',
        myRole: TripRole.host,
        createdAt: DateTime.utc(2026, 10, 1),
      ) {
    repository = MemoryScheduleRepository(
      trip: trip,
      author: const ScheduleAuthor(
        memberId: 'sample-home-member-self',
        name: '나',
      ),
      hasSamples: true,
    );
  }
  final TripDetail trip;
  late final ScheduleRepository repository;
}
