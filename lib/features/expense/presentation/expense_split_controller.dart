import 'package:flutter/foundation.dart';

import '../data/expense_request.dart';
import '../data/expense_split_repository.dart';
import 'expense_split_preview.dart';
import 'expense_split_selection.dart';

class ExpenseSplitController extends ChangeNotifier {
  ExpenseSplitController(this._repository);

  final ExpenseSplitRepository _repository;
  ExpenseSplitData? _data;
  List<ExpenseSplitItem> _items = const [];
  ExpenseSplitPreview? _preview;
  String _payerMemberId = '';
  bool _isEqual = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDisposed = false;
  int _loadVersion = 0;

  ExpenseSplitData? get data => _data;
  List<ExpenseSplitItem> get items => List.unmodifiable(_items);
  ExpenseSplitPreview? get preview => _preview;
  String get payerMemberId => _payerMemberId;
  bool get isEqual => _isEqual;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  Future<void> load() async {
    final version = ++_loadVersion;
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      final loaded = await _repository.loadSplitData();
      if (_isDisposed || version != _loadVersion) {
        return;
      }
      _data = loaded;
      _items = loaded.items;
      _payerMemberId = loaded.payerMemberId;
      _isEqual = loaded.initialSplitMethod == SplitMethod.equal;
      _recalculate();
      _hasError = _preview == null;
    } on Object {
      if (_isDisposed || version != _loadVersion) {
        return;
      }
      _hasError = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  void setEqual(bool value) {
    _isEqual = value;
    _update();
  }

  void setPayer(String memberId) {
    if (_data?.members.any((member) => member.memberId == memberId) != true) {
      return;
    }
    _payerMemberId = memberId;
    _update();
  }

  void toggleMember(
    int itemIndex,
    String memberId, {
    required bool isSelected,
  }) {
    if (_data?.members.any((member) => member.memberId == memberId) != true ||
        itemIndex < 0 ||
        itemIndex >= _items.length) {
      return;
    }
    final selected = Set<String>.of(_items[itemIndex].memberIds);
    if (isSelected) {
      selected.add(memberId);
    } else {
      selected.remove(memberId);
    }
    _items = [
      for (var i = 0; i < _items.length; i++)
        i == itemIndex ? _items[i].withMembers(selected) : _items[i],
    ];
    _update();
  }

  /// Builds the documented POST body without sending or saving the demo.
  ExpenseRequest? createRequest() {
    final current = _data;
    if (current == null || _preview == null || _isLoading || _hasError) {
      return null;
    }
    ExpenseRequestItem requestItem(ExpenseSplitItem item) => ExpenseRequestItem(
      name: item.name,
      amountLocal: current.currencyCode == 'KRW' ? null : item.amountLocal,
      amountKrw: current.currencyCode == 'KRW'
          ? item.amountLocal.round()
          : null,
      members: item.memberIds
          .map((id) => ExpenseRequestMember(memberId: id))
          .toList(),
    );
    return ExpenseRequest(
      payerMemberId: _payerMemberId,
      title: current.title,
      category: current.category,
      paidDate: current.paidDate,
      // The fixture is a fixed rate, so its request uses MANUAL, not API.
      rateMode: current.currencyCode == 'KRW' ? RateMode.krw : RateMode.manual,
      manualRate: current.currencyCode == 'KRW' ? null : current.previewRate,
      amountLocal: current.currencyCode == 'KRW' ? null : _preview!.totalLocal,
      amountKrw: current.currencyCode == 'KRW' ? _preview!.totalWon : null,
      splitMethod: _isEqual ? SplitMethod.equal : SplitMethod.item,
      items: _isEqual
          ? [
              ExpenseRequestItem(
                name: current.title,
                amountLocal: current.currencyCode == 'KRW'
                    ? null
                    : _preview!.totalLocal,
                amountKrw: current.currencyCode == 'KRW'
                    ? _preview!.totalWon
                    : null,
                members: current.members
                    .map(
                      (member) =>
                          ExpenseRequestMember(memberId: member.memberId),
                    )
                    .toList(),
              ),
            ]
          : _items.map(requestItem).toList(),
    );
  }

  ExpenseSplitSelection? createSelection() {
    final request = createRequest();
    if (request == null) {
      return null;
    }
    final current = _data!;
    return ExpenseSplitSelection(
      request: request,
      preview: _preview!,
      data: ExpenseSplitData(
        tripName: current.tripName,
        title: current.title,
        paidDate: current.paidDate,
        payerMemberId: _payerMemberId,
        previewRate: current.previewRate,
        category: current.category,
        currencyCode: current.currencyCode,
        initialSplitMethod: _isEqual ? SplitMethod.equal : SplitMethod.item,
        members: current.members,
        items: _items,
      ),
    );
  }

  void _update() {
    _recalculate();
    notifyListeners();
  }

  void _recalculate() {
    final current = _data;
    if (current == null) {
      return;
    }
    _preview = calculateSplitPreview(
      _items,
      members: current.members,
      payerMemberId: _payerMemberId,
      rate: current.previewRate,
      isEqual: _isEqual,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
