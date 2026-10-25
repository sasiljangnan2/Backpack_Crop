import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../expense_split_strings.dart';
import '../expense_strings.dart';

import 'package:flutter/services.dart';

import '../../data/expense_split_repository.dart';
import '../expense_split_preview.dart';

class ExpenseSplitResultSheet extends StatelessWidget {
  const ExpenseSplitResultSheet({
    super.key,
    required this.data,
    required this.result,
    required this.isEqual,
    required this.payerMemberId,
    required this.onCopied,
    this.onConfirm,
  });

  final ExpenseSplitData data;
  final ExpenseSplitPreview result;
  final bool isEqual;
  final String payerMemberId;
  final VoidCallback onCopied;
  final VoidCallback? onConfirm;

  List<ExpenseSplitMember> get _members => data.members;
  bool get _isEqual => isEqual;
  int get _payer =>
      _members.indexWhere((member) => member.memberId == payerMemberId);

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              ExpenseSplitStrings.resultTitle,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              ExpenseSplitStrings.resultSubtitle(data.title, _isEqual),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                children: [
                  for (var person = 0; person < _members.length; person++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primarySoft,
                            child: Text(
                              _members[person].name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _members[person].name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (person == _payer)
                                  const Text(
                                    ExpenseSplitStrings.payer,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                if (result.adjustments[person] != 0)
                                  Text(
                                    ExpenseSplitStrings.adjustment(
                                      result.adjustments[person],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₩${ExpenseSplitStrings.money(result.amountsWon[person])}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                ExpenseSplitStrings.amount(
                                  result.localAmounts[person],
                                  data.currencyCode,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          ExpenseSplitStrings.totalShare,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '₩${ExpenseSplitStrings.money(result.totalWon)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    ExpenseSplitStrings.resultNote,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (onConfirm != null) ...[
              FilledButton(
                key: const ValueKey('apply-split'),
                onPressed: onConfirm,
                child: const Text(ExpenseStrings.confirmSplit),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: () async {
                final lines = [
                  ExpenseSplitStrings.resultSubtitle(data.title, _isEqual),
                  ExpenseSplitStrings.copyTotal(
                    result.totalLocal,
                    result.totalWon,
                    data.currencyCode,
                  ),
                  for (var i = 0; i < _members.length; i++)
                    '${_members[i].name}: ₩${ExpenseSplitStrings.money(result.amountsWon[i])}',
                  ExpenseSplitStrings.copyRate(
                    data.previewRate,
                    data.currencyCode,
                  ),
                ];
                await Clipboard.setData(ClipboardData(text: lines.join('\n')));
                if (context.mounted) {
                  Navigator.pop(context);
                  onCopied();
                }
              },
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text(ExpenseSplitStrings.copy),
            ),
          ],
        ),
      ),
    ),
  );
}
