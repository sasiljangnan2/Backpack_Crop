import '../../../core/network/api_exception.dart';
import 'trip_repository.dart';

/// Isolated preview data. No credentials or HTTP requests are involved.
class SampleTripRepository implements TripRepository {
  SampleTripRepository() {
    _trips.add(
      TripDetail(
        id: 'preview-trip-0',
        name: '친구들과 오사카',
        destination: '일본 오사카',
        startDate: '2026-11-01',
        endDate: '2026-11-05',
        currencyCode: 'JPY',
        inviteCode: 'DEMO2026',
        myMemberId: _me,
        myRole: TripRole.host,
        createdAt: DateTime.utc(2026, 10, 27),
      ),
    );
  }
  static const String _me = 'preview-member-self';
  final List<TripDetail> _trips = [];
  int _nextId = 1;
  @override
  Future<List<TripSummary>> list() async =>
      _trips.map((trip) => trip.toSummary(memberCount: 2)).toList();
  @override
  Future<TripDetail> create(TripCreateRequest request) async {
    final number = _nextId++;
    final trip = TripDetail(
      id: 'preview-trip-$number',
      name: request.name.trim(),
      destination: request.destination.trim(),
      startDate: request.startDate,
      endDate: request.endDate,
      currencyCode: request.currencyCode,
      inviteCode: 'DEMO${number.toString().padLeft(4, '0')}',
      myMemberId: _me,
      myRole: TripRole.host,
      createdAt: DateTime.now().toUtc(),
    );
    _trips.insert(0, trip);
    return trip;
  }

  @override
  Future<TripDetail> detail(String tripId) async =>
      _trips.firstWhere((trip) => trip.id == tripId);
  @override
  Future<List<TripMember>> members(String tripId) async => [
    TripMember(
      memberId: _me,
      name: '나',
      role: TripRole.host,
      isMe: true,
      joinedAt: DateTime.utc(2026, 10, 27),
    ),
    TripMember(
      memberId: 'preview-member-friend',
      name: '동행 1',
      role: TripRole.member,
      isMe: false,
      joinedAt: DateTime.utc(2026, 10, 27),
    ),
  ];
  @override
  Future<TripDetail> join(String code) async {
    for (final trip in _trips) {
      if (trip.inviteCode == code.trim().toUpperCase()) {
        return trip;
      }
    }
    throw const ApiException(
      status: 404,
      code: 'NOT_FOUND',
      message: '미리보기에서는 DEMO2026 코드를 사용해 보세요.',
    );
  }
}
