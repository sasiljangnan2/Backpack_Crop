import '../../trip/data/trip_repository.dart';
import '../data/memory_schedule_repository.dart';
import '../data/schedule_models.dart';

class SchedulePreviews {
  final Map<String, MemoryScheduleRepository> _repositories = {};
  MemoryScheduleRepository forTrip(TripDetail trip, List<TripMember> members) =>
      _repositories.putIfAbsent(trip.id, () {
        final names = members.where(
          (member) => member.memberId == trip.myMemberId,
        );
        return MemoryScheduleRepository(
          trip: trip,
          hasSamples: true,
          author: ScheduleAuthor(
            memberId: trip.myMemberId,
            name: names.isEmpty ? '나' : names.first.name,
          ),
        );
      });
}
