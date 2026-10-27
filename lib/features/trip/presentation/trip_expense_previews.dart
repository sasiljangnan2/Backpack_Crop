import '../../expense/data/expense_repository.dart';
import '../../expense/data/expense_split_repository.dart';
import '../../expense/data/memory_expense_repository.dart';
import '../data/trip_repository.dart';

/// Separate session-only expense previews for each server trip.
class TripExpensePreviews {
  final Map<String, MemoryExpenseRepository> _repositories = {};
  MemoryExpenseRepository forTrip(TripDetail trip, List<TripMember> members) =>
      _repositories.putIfAbsent(
        trip.id,
        () => MemoryExpenseRepository(
          trip: ExpenseTripContext(
            tripName: trip.name,
            currentMemberId: trip.myMemberId,
            defaultDate: trip.startDate,
            currencyCode: trip.currencyCode,
            previewRate: trip.currencyCode == 'KRW' ? 1 : 9.35,
            members: members
                .map(
                  (member) => ExpenseSplitMember(
                    memberId: member.memberId,
                    name: member.name,
                  ),
                )
                .toList(),
          ),
        ),
      );
}
