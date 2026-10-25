import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../expense_split_strings.dart';
import '../../data/expense_split_repository.dart';
import '../expense_split_controller.dart';
import '../expense_split_preview.dart';
import 'expense_split_item_row.dart';

class ExpenseSplitContent extends StatelessWidget {
  const ExpenseSplitContent({
    super.key,
    required this.controller,
    required this.onHelp,
    required this.onResult,
  });

  final ExpenseSplitController controller;
  final VoidCallback onHelp;
  final ValueChanged<ExpenseSplitPreview> onResult;

  ExpenseSplitData get _data => controller.data!;
  List<ExpenseSplitItem> get _items => controller.items;
  List<ExpenseSplitMember> get _members => _data.members;
  ExpenseSplitPreview? get _preview => controller.preview;
  bool get _isEqual => controller.isEqual;
  int get _payer => _members.indexWhere(
    (member) => member.memberId == controller.payerMemberId,
  );
  num get _total => _items.fold<num>(0, (sum, item) => sum + item.amountLocal);

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final missing = _items.where((item) => item.memberIds.isEmpty).length;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: AppColors.scheme,
        scaffoldBackgroundColor: Colors.white,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            ExpenseSplitStrings.title,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            tooltip: ExpenseSplitStrings.back,
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.chevron_left, size: 28),
          ),
          actions: [
            IconButton(
              tooltip: ExpenseSplitStrings.help,
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline, color: AppColors.muted),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        ExpenseSplitStrings.sample,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ExpenseSplitStrings.tripCategory(
                          _data.tripName,
                          _data.category,
                        ),
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _data.title,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ExpenseSplitStrings.amount(_total, _data.currencyCode),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          ExpenseSplitStrings.approximateWon(
                            (_total * _data.previewRate).round(),
                          ),
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ExpenseSplitStrings.sampleRate(
                    _data.previewRate,
                    _data.currencyCode,
                  ),
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.credit_card_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      ExpenseSplitStrings.payer,
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(width: 12),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: controller.payerMemberId,
                        isDense: true,
                        borderRadius: BorderRadius.circular(14),
                        items: [
                          for (var i = 0; i < _members.length; i++)
                            DropdownMenuItem(
                              value: _members[i].memberId,
                              child: Text(
                                _members[i].name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            controller.setPayer(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text(ExpenseSplitStrings.equal),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(ExpenseSplitStrings.item),
                    ),
                  ],
                  selected: {_isEqual},
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.primarySoft,
                    selectedForegroundColor: AppColors.primary,
                    minimumSize: const Size(0, 48),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onSelectionChanged: (values) =>
                      controller.setEqual(values.single),
                ),
                const SizedBox(height: 24),
                Text(
                  _isEqual
                      ? ExpenseSplitStrings.equalPeople(_members.length)
                      : ExpenseSplitStrings.choosePeople,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _isEqual
                      ? ExpenseSplitStrings.equalHint
                      : ExpenseSplitStrings.itemHint,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                for (var itemIndex = 0; itemIndex < _items.length; itemIndex++)
                  ExpenseSplitItemRow(
                    index: itemIndex,
                    item: _items[itemIndex],
                    members: _members,
                    isEqual: _isEqual,
                    currencyCode: _data.currencyCode,
                    onSelected: (id, selected) => controller.toggleMember(
                      itemIndex,
                      id,
                      isSelected: selected,
                    ),
                  ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.muted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ExpenseSplitStrings.roundingHint,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.65,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.background)),
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (preview != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ExpenseSplitStrings.payerShare(
                                _members[_payer].name,
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Text(
                            '₩${ExpenseSplitStrings.money(preview.amountsWon[_payer])}',
                            key: const ValueKey('payer-share'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ExpenseSplitStrings.missingPeople(missing),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: preview == null
                          ? null
                          : () => onResult(preview),
                      child: const Text(
                        ExpenseSplitStrings.confirm,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
