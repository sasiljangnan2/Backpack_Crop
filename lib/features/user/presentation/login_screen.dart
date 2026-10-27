import 'package:flutter/material.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import 'auth_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialEmail = '', this.notice});
  final String initialEmail;
  final String? notice;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  final _password = TextEditingController();
  bool _isBusy = false;
  bool _isHidden = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isBusy || !_form.currentState!.validate()) {
      return;
    }
    final auth = AppScope.of(context).auth;
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await auth.login(_email.text, _password.text);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.status == 401
              ? AuthStrings.invalidLogin
              : error.displayMessage,
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _error = AuthStrings.failed);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_isBusy,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(AuthStrings.login),
        leading: IconButton(
          onPressed: _isBusy ? null : () => Navigator.maybePop(context),
          tooltip: AuthStrings.back,
          icon: const Icon(Icons.chevron_left),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            const Icon(
              Icons.backpack_outlined,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              AuthStrings.loginTitle,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              AuthStrings.loginHint,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            if (widget.notice != null) ...[
              Text(
                widget.notice!,
                style: const TextStyle(color: AppColors.success),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const ValueKey('login-email'),
              controller: _email,
              enabled: !_isBusy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: AuthStrings.email,
                hintText: AuthStrings.emailHint,
              ),
              validator: (value) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value!.trim()) &&
                      value.trim().length <= 255
                  ? null
                  : AuthStrings.emailInvalid,
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('login-password'),
              controller: _password,
              enabled: !_isBusy,
              obscureText: _isHidden,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: AuthStrings.password,
                hintText: AuthStrings.passwordHint,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _isHidden = !_isHidden),
                  tooltip: _isHidden
                      ? AuthStrings.showPassword
                      : AuthStrings.hidePassword,
                  icon: Icon(
                    _isHidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  value!.isEmpty ? AuthStrings.passwordRequired : null,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                key: const ValueKey('login-error'),
                style: const TextStyle(color: AppColors.error),
              ),
            const SizedBox(height: 32),
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
            key: const ValueKey('login-submit'),
            onPressed: _isBusy ? null : _submit,
            child: Text(_isBusy ? AuthStrings.saving : AuthStrings.login),
          ),
        ),
      ),
    ),
  );
}
