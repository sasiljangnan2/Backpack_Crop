import 'package:flutter/material.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../data/trip_repository.dart';
import 'trip_create_screen.dart';
import 'trip_join_screen.dart';
import 'trip_expense_previews.dart';
import 'trip_overview_screen.dart';
import 'trip_strings.dart';
import 'widgets/trip_card.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({
    super.key,
    required this.repository,
    this.isPreview = false,
  });
  final TripRepository repository;
  final bool isPreview;
  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  final _expensePreviews = TripExpensePreviews();
  List<TripSummary> _trips = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;
  int _loadVersion = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final trips = await widget.repository.list();
      if (!mounted || version != _loadVersion) {
        return;
      }
      setState(() => _trips = trips);
    } on ApiException catch (error) {
      if (mounted && version == _loadVersion) {
        setState(
          () => _error = error.status == 404
              ? TripStrings.pendingApi
              : error.displayMessage,
        );
      }
    } on Object {
      if (mounted && version == _loadVersion) {
        setState(() => _error = TripStrings.loadError);
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createOrJoin({bool isJoining = false}) async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    final trip = await Navigator.push<TripDetail>(
      context,
      MaterialPageRoute(
        builder: (_) => isJoining
            ? TripJoinScreen(
                repository: widget.repository,
                isPreview: widget.isPreview,
              )
            : TripCreateScreen(
                repository: widget.repository,
                isPreview: widget.isPreview,
              ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isBusy = false);
    if (trip == null) {
      return;
    }
    setState(
      () => _trips = [
        trip.toSummary(memberCount: 1),
        ..._trips.where((item) => item.id != trip.id),
      ],
    );
    await _open(trip.id, initial: trip);
    if (mounted) {
      _load();
    }
  }

  Future<void> _open(String id, {TripDetail? initial}) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => TripOverviewScreen(
        tripId: id,
        repository: widget.repository,
        expensePreviews: _expensePreviews,
        initial: initial,
        isPreview: widget.isPreview,
      ),
    ),
  );

  Future<void> _logout() async {
    if (_isBusy) {
      return;
    }
    final auth = AppScope.of(context).auth;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(TripStrings.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(TripStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(TripStrings.logout),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await auth.logout();
    } on Object {
      if (mounted) {
        setState(() => _error = TripStrings.failed);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(TripStrings.title),
      actions: [
        if (!widget.isPreview)
          IconButton(
            tooltip: TripStrings.logout,
            onPressed: _isBusy ? null : _logout,
            icon: const Icon(Icons.logout_outlined),
          ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.isPreview) ...[
            const Text(
              TripStrings.previewNotice,
              style: TextStyle(color: AppColors.primary, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            TripStrings.headline,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            TripStrings.description,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                  TextButton(
                    onPressed: _load,
                    child: const Text(TripStrings.retry),
                  ),
                ],
              ),
            ),
          if (!_isLoading && _error == null && _trips.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.luggage_outlined,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 20),
                  Text(
                    TripStrings.empty,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text(
                    TripStrings.emptyHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          for (final trip in _trips)
            TripCard(
              key: ValueKey(trip.id),
              trip: trip,
              onTap: () => _open(trip.id),
            ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isBusy
                    ? null
                    : () => _createOrJoin(isJoining: true),
                child: const Text(TripStrings.join),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const ValueKey('trip-create'),
                onPressed: _isBusy ? null : _createOrJoin,
                child: const Text(TripStrings.create),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
