import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../data/trip_repository.dart';
import 'trip_strings.dart';

class TripJoinScreen extends StatefulWidget {
  const TripJoinScreen({
    super.key,
    required this.repository,
    this.isPreview = false,
  });
  final TripRepository repository;
  final bool isPreview;
  @override
  State<TripJoinScreen> createState() => _TripJoinScreenState();
}

class _TripJoinScreenState extends State<TripJoinScreen> {
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _isBusy = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isBusy || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final trip = await widget.repository.join(_code.text);
      if (mounted) {
        Navigator.pop(context, trip);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.displayMessage);
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(TripStrings.join)),
    resizeToAvoidBottomInset: false,
    body: Form(
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
            TripStrings.joinHint,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey('trip-code'),
            controller: _code,
            enabled: !_isBusy,
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            ],
            decoration: const InputDecoration(labelText: TripStrings.codeLabel),
            validator: (value) =>
                RegExp(r'^[a-zA-Z0-9]{8}$').hasMatch(value!.trim())
                ? null
                : TripStrings.codeInvalid,
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
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
          onPressed: _isBusy ? null : _submit,
          child: Text(_isBusy ? TripStrings.busy : TripStrings.join),
        ),
      ),
    ),
  );
}
