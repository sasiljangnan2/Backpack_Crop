import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../expense/presentation/expense_list_screen.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/presentation/schedule_previews.dart';
import '../../schedule/presentation/schedule_screen.dart';
import '../../schedule/presentation/schedule_strings.dart';
import '../../settlement/data/preview_settlement_repository.dart';
import '../../settlement/data/settlement_repository.dart';
import '../../settlement/presentation/settlement_screen.dart';
import '../../settlement/presentation/settlement_strings.dart';
import '../data/trip_repository.dart';
import 'trip_expense_previews.dart';
import 'trip_strings.dart';

class TripOverviewScreen extends StatefulWidget {
  const TripOverviewScreen({
    super.key,
    required this.tripId,
    required this.repository,
    required this.expensePreviews,
    this.initial,
    this.schedulePreviews,
    this.isPreview = false,
  });
  final String tripId;
  final bool isPreview;
  final TripRepository repository;
  final TripExpensePreviews expensePreviews;
  final TripDetail? initial;
  final SchedulePreviews? schedulePreviews;
  @override
  State<TripOverviewScreen> createState() => _TripOverviewScreenState();
}

class _TripOverviewScreenState extends State<TripOverviewScreen> {
  TripDetail? _trip;
  List<TripMember> _members = [];
  late final SchedulePreviews _schedulePreviews =
      widget.schedulePreviews ?? SchedulePreviews();
  bool _isLoading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _trip = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.repository.detail(widget.tripId),
        widget.repository.members(widget.tripId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _trip = results[0] as TripDetail;
        _members = results[1] as List<TripMember>;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.displayMessage);
      }
    } on Object {
      if (mounted) {
        setState(() => _error = TripStrings.detailError);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _trip!.inviteCode));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(TripStrings.copied)));
  }

  Future<void> _settlement(TripDetail trip) async {
    final expenses = widget.isPreview
        ? widget.expensePreviews.forTrip(trip, _members)
        : null;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SettlementScreen(
          tripName: trip.name,
          currentMemberId: trip.myMemberId,
          isPreview: widget.isPreview,
          repository: expenses != null
              ? PreviewSettlementRepository(expenses)
              : ApiSettlementRepository(AppScope.of(context).api, trip.id),
          onViewExpenses:
              expenses == null || !['JPY', 'KRW'].contains(trip.currencyCode)
              ? null
              : () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpenseListScreen(repository: expenses),
                    ),
                  );
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final canPreview =
        trip != null &&
        ['JPY', 'KRW'].contains(trip.currencyCode) &&
        _members.any((member) => member.memberId == trip.myMemberId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(TripStrings.overview)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _load,
                      child: const Text(TripStrings.retry),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (widget.isPreview) ...[
                  const Text(
                    TripStrings.previewNotice,
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  trip!.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${trip.destination} · ${trip.currencyCode}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Text(
                  TripStrings.range(trip.startDate, trip.endDate),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('schedule-open'),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScheduleScreen(
                        trip: trip,
                        isPreview: widget.isPreview,
                        repository: widget.isPreview
                            ? _schedulePreviews.forTrip(trip, _members)
                            : ApiScheduleRepository(
                                AppScope.of(context).api,
                                trip.id,
                              ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text(ScheduleStrings.open),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: AppColors.primarySoft,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          TripStrings.invite,
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          trip.inviteCode,
                          key: const ValueKey('trip-invite-code'),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text(TripStrings.copyInvite),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  TripStrings.members,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (final member in _members)
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          member.name.isEmpty
                              ? '?'
                              : member.name.characters.first,
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                      title: Text(member.name),
                      subtitle: Text(TripStrings.role(member.role)),
                      trailing: member.isMe
                          ? const Text(
                              TripStrings.me,
                              style: TextStyle(color: AppColors.primary),
                            )
                          : null,
                    ),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: !canPreview
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExpenseListScreen(
                              repository: widget.expensePreviews.forTrip(
                                trip,
                                _members,
                              ),
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text(TripStrings.expenses),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('settlement-open'),
                  onPressed: () => _settlement(trip),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text(SettlementStrings.open),
                ),
                const SizedBox(height: 10),
                Text(
                  ['JPY', 'KRW'].contains(trip.currencyCode)
                      ? TripStrings.expenseHint
                      : TripStrings.unsupportedCurrency,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
    );
  }
}
