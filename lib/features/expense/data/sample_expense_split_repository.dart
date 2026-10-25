import 'expense_split_repository.dart';

/// Supplies storyboard fixtures until the documented endpoints are available.
class SampleExpenseSplitRepository implements ExpenseSplitRepository {
  const SampleExpenseSplitRepository();

  @override
  Future<ExpenseSplitData> loadSplitData() async {
    const members = [
      ExpenseSplitMember(
        memberId: '019d0d00-0000-7000-8000-000000000001',
        name: '성진',
      ),
      ExpenseSplitMember(
        memberId: '019d0d00-0000-7000-8000-000000000002',
        name: '준휘',
      ),
      ExpenseSplitMember(
        memberId: '019d0d00-0000-7000-8000-000000000003',
        name: '진영',
      ),
      ExpenseSplitMember(
        memberId: '019d0d00-0000-7000-8000-000000000004',
        name: '진원',
      ),
      ExpenseSplitMember(
        memberId: '019d0d00-0000-7000-8000-000000000005',
        name: '재윤',
      ),
    ];
    Set<String> ids(List<int> positions) => {
      for (final position in positions) members[position].memberId,
    };
    return ExpenseSplitData(
      tripName: '오사카 4박 5일',
      title: '이치란 라멘 난바점',
      paidDate: '2026-11-01',
      payerMemberId: members.first.memberId,
      previewRate: 9.35,
      members: members,
      items: [
        ExpenseSplitItem(
          name: '돈코츠 라멘',
          quantity: 5,
          amountLocal: 4900,
          memberIds: ids([0, 1, 2, 3, 4]),
        ),
        ExpenseSplitItem(
          name: '생맥주',
          quantity: 3,
          amountLocal: 1650,
          memberIds: ids([0, 2, 3]),
        ),
        ExpenseSplitItem(
          name: '교자',
          quantity: 1,
          amountLocal: 390,
          memberIds: ids([1, 4]),
        ),
        ExpenseSplitItem(
          name: '차슈 추가',
          quantity: 1,
          amountLocal: 420,
          memberIds: ids([1]),
        ),
      ],
    );
  }
}
