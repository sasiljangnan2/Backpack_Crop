import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/format.dart';

/// 기존 경비 화면의 코랄 요약 카드. 금액은 서버 계산 결과를 그대로 표시한다.
class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({
    super.key,
    required this.totalKrw,
    required this.budgetKrw,
    required this.myShareKrw,
    this.hasOverviewError = false,
  });

  final int totalKrw;
  final int? budgetKrw;
  final int? myShareKrw;
  final bool hasOverviewError;

  @override
  Widget build(BuildContext context) {
    final budget = budgetKrw;
    return Container(
      key: const ValueKey('expense-summary'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('여행 공동 지출', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Fmt.krw(totalKrw),
                maxLines: 1,
                softWrap: false,
                style: AppTypography.money.copyWith(fontSize: 36),
              ),
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: budget == null || budget == 0
                  ? 0
                  : (totalKrw / budget).clamp(0, 1),
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: .3),
            ),
            const SizedBox(height: 10),
            Text(
              budget == null
                  ? hasOverviewError
                        ? '예산 정보를 불러오지 못했어요'
                        : '예산 정보 확인 중'
                  : budget == 0
                  ? '예산을 등록해 사용률을 확인하세요'
                  : '전체 예산 ${Fmt.krw(budget)}',
              style: const TextStyle(fontSize: 12),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: Color(0x55FFFFFF)),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text('내 부담액'),
                Text(
                  myShareKrw == null
                      ? hasOverviewError
                            ? '불러오기 실패'
                            : '확인 중'
                      : Fmt.krw(myShareKrw!),
                  style: AppTypography.money.copyWith(fontSize: 22),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
