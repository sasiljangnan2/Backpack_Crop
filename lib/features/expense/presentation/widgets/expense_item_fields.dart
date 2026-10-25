import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../expense_strings.dart';

class ExpenseItemFieldsState {
  ExpenseItemFieldsState({
    String name = '',
    String amount = '',
    required Set<String> memberIds,
    this.quantity = 1,
  }) : name = TextEditingController(text: name),
       amount = TextEditingController(text: amount),
       memberIds = Set.of(memberIds);

  final TextEditingController name;
  final TextEditingController amount;
  final int quantity;
  Set<String> memberIds;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class ExpenseItemFields extends StatelessWidget {
  const ExpenseItemFields({
    super.key,
    required this.state,
    required this.index,
    required this.currencyCode,
    this.onRemove,
  });

  final ExpenseItemFieldsState state;
  final int index;
  final String currencyCode;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ExpenseStrings.itemIndex(index),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: ExpenseStrings.removeItem,
                icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
              ),
            ],
          ),
          TextFormField(
            key: ValueKey('item-name-$index'),
            controller: state.name,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: ExpenseStrings.itemName,
              counterText: '',
            ),
            validator: (value) => value!.trim().isEmpty
                ? ExpenseStrings.itemRequired
                : value.trim().length > 100
                ? ExpenseStrings.nameTooLong
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: ValueKey('item-amount-$index'),
            controller: state.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: ExpenseStrings.itemAmount,
              suffixText: currencyCode,
            ),
            validator: (value) {
              final text = value!.trim();
              final amount = num.tryParse(text);
              if (amount == null ||
                  !amount.isFinite ||
                  amount <= 0 ||
                  amount > 100000000) {
                return ExpenseStrings.amountInvalid;
              }
              if (currencyCode == 'KRW' && !RegExp(r'^\d+$').hasMatch(text)) {
                return ExpenseStrings.wonInvalid;
              }
              if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
                return ExpenseStrings.decimalInvalid;
              }
              return null;
            },
          ),
        ],
      ),
    ),
  );
}
