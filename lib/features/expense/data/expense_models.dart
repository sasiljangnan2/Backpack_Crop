import 'package:flutter/material.dart';

import '../../../core/network/json.dart';
import '../../trip/data/trip_models.dart';

/// 지출 분류. 아이콘 · 지출 행 · 비율 막대 · 예산 막대에 같은 색을 쓴다 (스토리보드 BC-004 ⑤)
enum ExpenseCategory {
  food('식비', Icons.restaurant_outlined, Color(0xFFE8890C)),
  lodging('숙소', Icons.hotel_outlined, Color(0xFF7C4DDB)),
  transport('교통', Icons.directions_subway_outlined, Color(0xFF2D83F5)),
  activity('관광·체험', Icons.local_activity_outlined, Color(0xFFDB2777)),
  shopping('쇼핑', Icons.shopping_bag_outlined, Color(0xFF0891B2)),
  etc('기타', Icons.more_horiz, Color(0xFF64748B));

  const ExpenseCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// 환율 방식: API(그날 환율) · PREPAID(내가 환전해 간 환율) · MANUAL(직접 입력) · KRW(원화)
enum RateMode { api, prepaid, manual, krw }

/// 분담 방식: 균등 · 항목별 · 개별 금액
enum SplitMethod { equal, item, custom }

class ExchangeRate {
  const ExchangeRate({
    required this.currencyCode,
    required this.rateDate,
    required this.rateToKrw,
    required this.unit,
    required this.unitRateToKrw,
    required this.fetchedAt,
    required this.isFallback,
  });

  factory ExchangeRate.fromJson(Json json) => ExchangeRate(
    currencyCode: json['currencyCode'] as String,
    rateDate: date(json['rateDate']),
    rateToKrw: decimal(json['rateToKrw']),
    unit: integer(json['unit']),
    unitRateToKrw: decimal(json['unitRateToKrw']),
    fetchedAt: instantOrNull(json['fetchedAt']),
    isFallback: json['isFallback'] as bool? ?? false,
  );

  static ExchangeRate? fromJsonOrNull(Object? json) =>
      json == null ? null : ExchangeRate.fromJson(json as Json);

  final String currencyCode;
  final DateTime rateDate;
  final double rateToKrw;
  final int unit;
  final double unitRateToKrw;
  final DateTime? fetchedAt;
  final bool isFallback;
}

class ExpenseListItem {
  const ExpenseListItem({
    required this.id,
    required this.title,
    required this.category,
    required this.paidDate,
    required this.rateMode,
    required this.amountLocal,
    required this.amountKrw,
    required this.payer,
    required this.creator,
    required this.isPaidByMe,
    required this.myShareKrw,
  });

  factory ExpenseListItem.fromJson(Json json) => ExpenseListItem(
    id: json['id'] as String,
    title: json['title'] as String,
    category: enumOf(
      ExpenseCategory.values,
      json['category'],
      ExpenseCategory.etc,
    ),
    paidDate: date(json['paidDate']),
    rateMode: enumOf(RateMode.values, json['rateMode'], RateMode.krw),
    amountLocal: decimalOrNull(json['amountLocal']),
    amountKrw: integer(json['amountKrw']),
    payer: MemberRef.fromJson(json['payer'] as Json),
    creator: MemberRef.fromJsonOrNull(json['creator']),
    isPaidByMe: json['isPaidByMe'] as bool? ?? false,
    myShareKrw: integer(json['myShareKrw']),
  );

  final String id;
  final String title;
  final ExpenseCategory category;
  final DateTime paidDate;
  final RateMode rateMode;
  final double? amountLocal;
  final int amountKrw;
  final MemberRef payer;

  /// 입력한 사람. 결제자와 다르면 대리 입력
  final MemberRef? creator;
  final bool isPaidByMe;
  final int myShareKrw;

  bool get isProxy => creator != null && creator!.memberId != payer.memberId;
}

class ExpensePage {
  const ExpensePage({
    required this.content,
    required this.nextCursor,
    required this.hasNext,
    required this.count,
    required this.totalKrw,
    required this.todayRate,
    required this.byCategory,
  });

  factory ExpensePage.fromJson(Json json) {
    final summary = json['summary'] as Json;
    return ExpensePage(
      content: list(json['content'], ExpenseListItem.fromJson),
      nextCursor: json['nextCursor'] as String?,
      hasNext: json['hasNext'] as bool? ?? false,
      count: integer(summary['count']),
      totalKrw: integer(summary['totalKrw']),
      todayRate: ExchangeRate.fromJsonOrNull(summary['todayRate']),
      byCategory: [
        for (final item in (summary['byCategory'] as List?) ?? const [])
          (
            enumOf(
              ExpenseCategory.values,
              (item as Json)['category'],
              ExpenseCategory.etc,
            ),
            integer(item['amountKrw']),
          ),
      ],
    );
  }

  final List<ExpenseListItem> content;
  final String? nextCursor;
  final bool hasNext;
  final int count;
  final int totalKrw;
  final ExchangeRate? todayRate;

  /// 분류별 원화 합계, 금액이 큰 순 (비율 막대)
  final List<(ExpenseCategory, int)> byCategory;
}

class ExpenseShare {
  const ExpenseShare({
    required this.memberId,
    required this.name,
    required this.shareKrw,
  });

  factory ExpenseShare.fromJson(Json json) => ExpenseShare(
    memberId: json['memberId'] as String,
    name: json['name'] as String,
    shareKrw: integer(json['shareKrw']),
  );

  final String memberId;
  final String name;
  final int shareKrw;
}

class ExpenseItem {
  const ExpenseItem({
    required this.name,
    required this.amountLocal,
    required this.amountKrw,
    required this.remainderKrw,
    required this.remainderMember,
    required this.members,
  });

  factory ExpenseItem.fromJson(Json json) => ExpenseItem(
    name: json['name'] as String,
    amountLocal: decimalOrNull(json['amountLocal']),
    amountKrw: integer(json['amountKrw']),
    remainderKrw: integer(json['remainderKrw']),
    remainderMember: MemberRef.fromJsonOrNull(json['remainderMember']),
    members: list(json['members'], ExpenseShare.fromJson),
  );

  final String name;
  final double? amountLocal;
  final int amountKrw;
  final int remainderKrw;
  final MemberRef? remainderMember;
  final List<ExpenseShare> members;
}

class MemberShare {
  const MemberShare({
    required this.memberId,
    required this.name,
    required this.shareKrw,
    required this.shareLocal,
    required this.isPayer,
  });

  factory MemberShare.fromJson(Json json) => MemberShare(
    memberId: json['memberId'] as String,
    name: json['name'] as String,
    shareKrw: integer(json['shareKrw']),
    shareLocal: decimalOrNull(json['shareLocal']),
    isPayer: json['isPayer'] as bool? ?? false,
  );

  final String memberId;
  final String name;
  final int shareKrw;
  final double? shareLocal;
  final bool isPayer;
}

/// 지출 상세. 미리보기 응답은 [id]·[version]이 null이다.
class ExpenseDetail {
  const ExpenseDetail({
    required this.id,
    required this.title,
    required this.category,
    required this.paidDate,
    required this.currencyCode,
    required this.rateMode,
    required this.amountLocal,
    required this.appliedRate,
    required this.rateDate,
    required this.amountKrw,
    required this.splitMethod,
    required this.payer,
    required this.creator,
    required this.items,
    required this.memberShares,
    required this.version,
    this.createdAt,
    this.updatedAt,
  });

  factory ExpenseDetail.fromJson(Json json) => ExpenseDetail(
    id: json['id'] as String?,
    title: json['title'] as String,
    category: enumOf(
      ExpenseCategory.values,
      json['category'],
      ExpenseCategory.etc,
    ),
    paidDate: date(json['paidDate']),
    currencyCode: json['currencyCode'] as String,
    rateMode: enumOf(RateMode.values, json['rateMode'], RateMode.krw),
    amountLocal: decimalOrNull(json['amountLocal']),
    appliedRate: decimalOrNull(json['appliedRate']),
    rateDate: dateOrNull(json['rateDate']),
    amountKrw: integer(json['amountKrw']),
    splitMethod: enumOf(
      SplitMethod.values,
      json['splitMethod'],
      SplitMethod.equal,
    ),
    payer: MemberRef.fromJson(json['payer'] as Json),
    creator: MemberRef.fromJson(json['creator'] as Json),
    items: list(json['items'], ExpenseItem.fromJson),
    memberShares: list(json['memberShares'], MemberShare.fromJson),
    version: integerOrNull(json['version']),
    createdAt: instantOrNull(json['createdAt']),
    updatedAt: instantOrNull(json['updatedAt']),
  );

  final String? id;
  final String title;
  final ExpenseCategory category;
  final DateTime paidDate;
  final String currencyCode;
  final RateMode rateMode;
  final double? amountLocal;
  final double? appliedRate;
  final DateTime? rateDate;
  final int amountKrw;
  final SplitMethod splitMethod;
  final MemberRef payer;
  final MemberRef creator;
  final List<ExpenseItem> items;
  final List<MemberShare> memberShares;
  final DateTime? createdAt;

  /// 마지막으로 고친 시각 (만든 시각과 다르면 화면에 보인다)
  final DateTime? updatedAt;
  final int? version;

  int get remainderKrw => items.fold(0, (sum, item) => sum + item.remainderKrw);
}

/// 지출 등록 · 수정 · 미리보기 요청
class ExpenseDraft {
  ExpenseDraft({
    required this.payerMemberId,
    required this.title,
    required this.category,
    required this.paidDate,
    required this.rateMode,
    required this.splitMethod,
    this.amountLocal,
    this.amountKrw,
    this.manualRate,
    this.memberIds = const [],
    this.items = const [],
    this.version,
  });

  String payerMemberId;
  String title;
  ExpenseCategory category;
  DateTime paidDate;
  RateMode rateMode;
  SplitMethod splitMethod;
  double? amountLocal;
  int? amountKrw;
  double? manualRate;

  /// 균등 분담 대상
  List<String> memberIds;

  /// 항목별 · 개별 분담
  List<ExpenseItemDraft> items;
  int? version;

  Json toJson() => {
    'payerMemberId': payerMemberId,
    'title': title,
    'category': enumName(category),
    'paidDate': dateParam(paidDate),
    'rateMode': enumName(rateMode),
    'amountLocal': rateMode == RateMode.krw ? null : amountLocal,
    'amountKrw': rateMode == RateMode.krw ? amountKrw : null,
    'manualRate': rateMode == RateMode.manual ? manualRate : null,
    'splitMethod': enumName(splitMethod),
    'memberIds': splitMethod == SplitMethod.equal ? memberIds : null,
    'items': splitMethod == SplitMethod.equal
        ? null
        : [
            for (final item in items)
              item.toJson(splitMethod, rateMode == RateMode.krw),
          ],
    'version': version,
  };
}

class ExpenseItemDraft {
  ExpenseItemDraft({this.name = '', this.amount, Map<String, int?>? members})
    : members = members ?? {};

  String name;

  /// 항목 금액 (원화 지출이면 원, 아니면 여행 통화)
  double? amount;

  /// 분담자 → 개별 금액(원). 개별 분담(CUSTOM)에서만 금액을 쓴다
  Map<String, int?> members;

  Json toJson(SplitMethod method, bool krw) => {
    'name': name.trim().isEmpty ? null : name.trim(),
    'amountLocal': method == SplitMethod.item && !krw ? amount : null,
    'amountKrw': method == SplitMethod.item && krw ? amount?.round() : null,
    'members': [
      for (final entry in members.entries)
        {
          'memberId': entry.key,
          'shareKrw': method == SplitMethod.custom ? entry.value : null,
        },
    ],
  };
}
