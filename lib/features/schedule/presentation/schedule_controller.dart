import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../trip/data/trip_repository.dart';
import '../data/schedule_models.dart';
import '../data/schedule_repository.dart';
import 'schedule_strings.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController({required this.repository, required this.trip}) {
    final now = DateTime.now();
    final today = scheduleDateString(now);
    _day =
        today.compareTo(trip.startDate) >= 0 &&
            today.compareTo(trip.endDate) <= 0
        ? today
        : trip.startDate;
  }
  final ScheduleRepository repository;
  final TripDetail trip;
  late String _day;
  List<ScheduleRecord> _records = [];
  bool _isLoading = true, _isMutating = false, _isDisposed = false;
  int _loadVersion = 0;
  String? _error;
  String get day => _day;
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  bool get canEdit => trip.myRole != TripRole.guest;
  String? get error => _error;
  List<ScheduleRecord> get all => List.unmodifiable(_records);
  List<ScheduleRecord> get items =>
      List.unmodifiable(_records.where((item) => item.day == _day));
  int get durationMinutes =>
      items.fold(0, (total, item) => total + item.durationMinutes);
  int get lockedCount => items.where((item) => item.isLocked).length;
  Future<void> load() async {
    if (_isMutating) {
      return;
    }
    final version = ++_loadVersion;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final records = await repository.list();
      if (_isDisposed || version != _loadVersion) {
        return;
      }
      _records = _sorted(records);
    } on ApiException catch (error) {
      if (_isDisposed || version != _loadVersion) {
        return;
      }
      _error = error.displayMessage;
    } on Object {
      if (_isDisposed || version != _loadVersion) {
        return;
      }
      _error = ScheduleStrings.loadError;
    }
    _isLoading = false;
    notifyListeners();
  }

  void selectDay(String day) {
    if (day.compareTo(trip.startDate) < 0 || day.compareTo(trip.endDate) > 0) {
      return;
    }
    _day = day;
    notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    if (_isMutating || !canEdit) {
      throw StateError('Schedule mutation is unavailable');
    }
    ++_loadVersion;
    _isLoading = false;
    _isMutating = true;
    notifyListeners();
    try {
      return await operation();
    } finally {
      if (!_isDisposed) {
        _isMutating = false;
        notifyListeners();
      }
    }
  }

  void _apply(ScheduleRecord saved) {
    if (_isDisposed) {
      return;
    }
    _records = _sorted([
      saved,
      ..._records.where((item) => item.id != saved.id),
    ]);
    _day = saved.day;
  }

  Future<ScheduleRecord> save(ScheduleDraft draft, {ScheduleRecord? current}) =>
      _run(() async {
        final saved = current == null
            ? await repository.create(draft)
            : await repository.update(current, draft);
        _apply(saved);
        return saved;
      });
  Future<void> lock(ScheduleRecord record, {required bool isLocked}) =>
      _run(() async {
        _apply(await repository.setLocked(record, isLocked: isLocked));
      });
  Future<void> remove(ScheduleRecord record) => _run(() async {
    await repository.delete(record);
    if (!_isDisposed) {
      _records = _records.where((item) => item.id != record.id).toList();
    }
  });
  List<ScheduleRecord> _sorted(List<ScheduleRecord> records) =>
      [...records]..sort((a, b) {
        final day = a.day.compareTo(b.day);
        return day != 0 ? day : a.startTime.compareTo(b.startTime);
      });
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
