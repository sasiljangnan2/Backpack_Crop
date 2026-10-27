import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../data/trip_repository.dart';
import 'trip_strings.dart';

class TripCreateScreen extends StatefulWidget {
  const TripCreateScreen({
    super.key,
    required this.repository,
    this.isPreview = false,
  });
  final TripRepository repository;
  final bool isPreview;
  @override
  State<TripCreateScreen> createState() => _TripCreateScreenState();
}

class _TripCreateScreenState extends State<TripCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _destination = TextEditingController();
  DateTimeRange? _dates;
  String _currency = 'JPY';
  bool _isBusy = false;
  bool _hasDateError = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _destination.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dates,
      helpText: TripStrings.period,
      saveText: TripStrings.selectDates,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _dates = picked;
      _hasDateError = false;
    });
  }

  Future<void> _submit() async {
    if (_isBusy) {
      return;
    }
    final isValid = _form.currentState!.validate();
    setState(() => _hasDateError = _dates == null);
    if (!isValid || _dates == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final trip = await widget.repository.create(
        TripCreateRequest(
          name: _name.text,
          destination: _destination.text,
          startDate: TripStrings.dateParam(_dates!.start),
          endDate: TripStrings.dateParam(_dates!.end),
          currencyCode: _currency,
        ),
      );
      if (mounted) {
        Navigator.pop(context, trip);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.status == 404
              ? TripStrings.pendingApi
              : error.displayMessage,
        );
      }
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
  Widget build(BuildContext context) => PopScope<TripDetail>(
    canPop: !_isBusy,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(TripStrings.create)),
      resizeToAvoidBottomInset: false,
      body: AbsorbPointer(
        absorbing: _isBusy,
        child: Form(
          key: _form,
          child: ListView(
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
                TripStrings.createHint,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('trip-name'),
                controller: _name,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: TripStrings.name,
                  hintText: TripStrings.nameHint,
                  counterText: '',
                ),
                validator: (value) =>
                    value!.trim().isEmpty || value.trim().length > 50
                    ? TripStrings.invalidName
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('trip-destination'),
                controller: _destination,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: TripStrings.destination,
                  hintText: TripStrings.destinationHint,
                  counterText: '',
                ),
                validator: (value) =>
                    value!.trim().isEmpty || value.trim().length > 100
                    ? TripStrings.invalidDestination
                    : null,
              ),
              const SizedBox(height: 24),
              const Text(
                TripStrings.period,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('trip-dates'),
                onPressed: _pickDates,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _dates == null
                      ? TripStrings.selectDates
                      : TripStrings.range(
                          TripStrings.dateParam(_dates!.start),
                          TripStrings.dateParam(_dates!.end),
                        ),
                ),
              ),
              if (_hasDateError)
                const Text(
                  TripStrings.dateRequired,
                  style: TextStyle(color: AppColors.error),
                ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: TripStrings.currency,
                ),
                items: const [
                  DropdownMenuItem(value: 'JPY', child: Text(TripStrings.yen)),
                  DropdownMenuItem(value: 'KRW', child: Text(TripStrings.won)),
                  DropdownMenuItem(
                    value: 'USD',
                    child: Text(TripStrings.dollars),
                  ),
                  DropdownMenuItem(
                    value: 'EUR',
                    child: Text(TripStrings.euros),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _currency = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: FilledButton(
            key: const ValueKey('trip-create-submit'),
            onPressed: _isBusy ? null : _submit,
            child: Text(_isBusy ? TripStrings.busy : TripStrings.create),
          ),
        ),
      ),
    ),
  );
}
