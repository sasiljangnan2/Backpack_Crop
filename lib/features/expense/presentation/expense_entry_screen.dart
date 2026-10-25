import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../data/expense_repository.dart';
import '../data/expense_request.dart';
import '../data/expense_split_repository.dart';
import 'expense_split_screen.dart';
import 'expense_split_selection.dart';
import 'expense_split_strings.dart';
import 'expense_strings.dart';
import 'widgets/expense_item_fields.dart';

class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({
    super.key,
    required this.trip,
    required this.onSave,
    this.initial,
  });

  final ExpenseTripContext trip;
  final Future<ExpenseRecord> Function(ExpenseSplitSelection selection) onSave;
  final ExpenseRecord? initial;

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _date;
  late final TextEditingController _rate;
  late final List<ExpenseItemFieldsState> _items;
  late String _payerId;
  late String _currency;
  late ExpenseCategory _category;
  late SplitMethod _method;
  bool _isSaving = false;
  bool _isChoosingSplit = false;
  bool _hasSaveError = false;
  bool _hasChanges = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial?.data;
    _title = TextEditingController(text: initial?.title ?? '');
    _date = TextEditingController(
      text: initial?.paidDate ?? widget.trip.defaultDate,
    );
    _rate = TextEditingController(
      text:
          (initial?.currencyCode == 'KRW'
                  ? widget.trip.previewRate
                  : initial?.previewRate ?? widget.trip.previewRate)
              .toString(),
    );
    _payerId = initial?.payerMemberId ?? widget.trip.currentMemberId;
    _currency = initial?.currencyCode ?? widget.trip.currencyCode;
    _category = initial?.category ?? ExpenseCategory.food;
    _method = initial?.initialSplitMethod ?? SplitMethod.equal;
    _items =
        initial?.items
            .map(
              (item) => ExpenseItemFieldsState(
                name: item.name,
                amount: item.amountLocal.toString(),
                memberIds: item.memberIds,
                quantity: item.quantity,
              ),
            )
            .toList() ??
        [_newItem()];
  }

  ExpenseItemFieldsState _newItem() => ExpenseItemFieldsState(
    memberIds: widget.trip.members.map((member) => member.memberId).toSet(),
  );

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _rate.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _changed() {
    setState(() {
      _hasChanges = true;
      _hasSaveError = false;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date.text),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || selected == null) {
      return;
    }
    _date.text =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    _changed();
  }

  Future<void> _leave() async {
    if (_isSaving) {
      return;
    }
    final shouldLeave =
        !_hasChanges ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text(ExpenseStrings.unsavedTitle),
                content: const Text(ExpenseStrings.unsavedBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(ExpenseStrings.stay),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(ExpenseStrings.leave),
                  ),
                ],
              ),
            ) ==
            true;
    if (!mounted || !shouldLeave) {
      return;
    }
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _next() async {
    if (_isSaving || _isChoosingSplit || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final draft = ExpenseSplitData(
      tripName: widget.trip.tripName,
      title: _title.text.trim(),
      paidDate: _date.text,
      payerMemberId: _payerId,
      category: _category,
      currencyCode: _currency,
      previewRate: _currency == 'KRW' ? 1 : num.parse(_rate.text.trim()),
      initialSplitMethod: _method,
      members: widget.trip.members,
      items: _items
          .map(
            (item) => ExpenseSplitItem(
              name: item.name.text.trim(),
              quantity: item.quantity,
              amountLocal: num.parse(item.amount.text.trim()),
              memberIds: item.memberIds,
            ),
          )
          .toList(),
    );
    setState(() => _isChoosingSplit = true);
    final selection = await Navigator.push<ExpenseSplitSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseSplitScreen(
          repository: DraftExpenseSplitRepository(draft),
          canConfirm: true,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isChoosingSplit = false);
    if (selection == null) {
      return;
    }
    _method = selection.request.splitMethod;
    _payerId = selection.request.payerMemberId;
    for (var i = 0; i < _items.length; i++) {
      _items[i].memberIds = selection.data.items[i].memberIds;
    }
    setState(() {
      _isSaving = true;
      _hasSaveError = false;
    });
    try {
      final saved = await widget.onSave(selection);
      if (!mounted) {
        return;
      }
      setState(() {
        _canPop = true;
        _isSaving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context, saved);
        }
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _hasSaveError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        errorMaxLines: 2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    ),
    child: PopScope<ExpenseRecord>(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leave();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            widget.initial == null ? ExpenseStrings.add : ExpenseStrings.edit,
          ),
          leading: IconButton(
            onPressed: _isSaving ? null : _leave,
            icon: const Icon(Icons.chevron_left),
            tooltip: ExpenseSplitStrings.back,
          ),
        ),
        body: Form(
          key: _form,
          onChanged: _changed,
          child: AbsorbPointer(
            absorbing: _isSaving,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  ExpenseStrings.sample,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('expense-title'),
                  controller: _title,
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: ExpenseStrings.titleLabel,
                    hintText: ExpenseStrings.titleHint,
                    counterText: '',
                  ),
                  validator: (value) => value!.trim().isEmpty
                      ? ExpenseStrings.titleRequired
                      : value.trim().length > 100
                      ? ExpenseStrings.nameTooLong
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('expense-date'),
                  controller: _date,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    labelText: ExpenseStrings.date,
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: ExpenseStrings.category,
                  ),
                  items: [
                    for (final category in ExpenseCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Text(ExpenseStrings.categoryLabel(category)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _category = value;
                      _changed();
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('expense-payer-$_payerId'),
                  initialValue: _payerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: ExpenseStrings.payer,
                  ),
                  items: [
                    for (final member in widget.trip.members)
                      DropdownMenuItem(
                        value: member.memberId,
                        child: Text(member.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _payerId = value;
                      _changed();
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('expense-currency'),
                  initialValue: _currency,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: ExpenseStrings.currency,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'JPY',
                      child: Text(ExpenseStrings.yen),
                    ),
                    DropdownMenuItem(
                      value: 'KRW',
                      child: Text(ExpenseStrings.won),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _currency = value;
                      });
                      _changed();
                    }
                  },
                ),
                if (_currency == 'JPY') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('expense-rate'),
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: ExpenseStrings.rate,
                      helperText: ExpenseStrings.rateHint,
                    ),
                    validator: (value) {
                      final rate = num.tryParse(value!.trim());
                      if (rate == null ||
                          !rate.isFinite ||
                          rate <= 0 ||
                          rate > 1000000) {
                        return ExpenseStrings.rateInvalid;
                      }
                      if (!RegExp(r'^\d+(\.\d{1,6})?$')
                          .hasMatch(value.trim())) {
                        return ExpenseStrings.ratePrecision;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 28),
                const Text(
                  ExpenseStrings.items,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  ExpenseStrings.formHint,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _items.length; i++)
                  ExpenseItemFields(
                    key: ObjectKey(_items[i]),
                    state: _items[i],
                    index: i,
                    currencyCode: _currency,
                    onRemove: _items.length == 1
                        ? null
                        : () {
                            final removed = _items.removeAt(i);
                            _changed();
                            // Form fields detach at the next frame before their controllers.
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => removed.dispose(),
                            );
                          },
                  ),
                if (_items.length < 20)
                  OutlinedButton.icon(
                    onPressed: () {
                      _items.add(_newItem());
                      _changed();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text(ExpenseStrings.addItem),
                  ),
                const SizedBox(height: 16),
                if (_hasSaveError)
                  const Text(
                    ExpenseStrings.saveError,
                    style: TextStyle(color: AppColors.error),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: FilledButton(
              key: const ValueKey('expense-next'),
              onPressed: _isSaving || _isChoosingSplit ? null : _next,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const Text(ExpenseStrings.saving)
                  : const Text(ExpenseStrings.next),
            ),
          ),
        ),
        resizeToAvoidBottomInset: false,
      ),
    ),
  );
}
