import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/settlement_models.dart';
import '../data/settlement_repository.dart';
import 'settlement_strings.dart';

class SettlementController extends ChangeNotifier {
  SettlementController({
    required this.repository,
    required this.currentMemberId,
  });
  final SettlementRepository repository;
  final String currentMemberId;
  SettlementSnapshot? _result;
  String? _error;
  DateTime? _checkedAt;
  bool _isLoading = true, _isDisposed = false, _isMine = true;
  int _loadVersion = 0;
  SettlementSnapshot? get result => _result;
  SettlementMember? get me => _result?.member(currentMemberId);
  String? get error => _error;
  DateTime? get checkedAt => _checkedAt;
  bool get isLoading => _isLoading;
  bool get isMine => _isMine && me != null;
  List<SettlementTransfer> get transfers => isMine
      ? _result!.transfersFor(currentMemberId)
      : _result?.transfers ?? const [];
  void selectMine(bool value) {
    _isMine = value;
    notifyListeners();
  }

  Future<void> load() async {
    final version = ++_loadVersion;
    _isLoading = true;
    _error = null;
    notifyListeners();
    SettlementSnapshot? result;
    String? error;
    try {
      result = await repository.load();
    } on ApiException catch (failure) {
      error = failure.displayMessage;
    } on FormatException {
      error = SettlementStrings.invalidData;
    } on TypeError {
      error = SettlementStrings.invalidData;
    } on Object {
      error = SettlementStrings.loadError;
    }
    if (_isDisposed || version != _loadVersion) {
      return;
    }
    if (result != null) {
      _result = result;
      _checkedAt = DateTime.now();
    }
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
