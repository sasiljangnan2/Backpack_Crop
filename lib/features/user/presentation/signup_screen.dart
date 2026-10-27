import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/app_dependencies.dart';
import '../../../core/network/api_exception.dart';
import 'auth_strings.dart';
import 'login_screen.dart';

const _primary = AppColors.primary;
const _ink = AppColors.ink;
const _muted = AppColors.muted;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _agreed = false;
  bool _isBusy = false;
  String? _error;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  bool get _passwordValid =>
      _password.text.length >= 8 && _password.text.length <= 64;
  bool get _emailValid =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim()) &&
      _email.text.trim().length <= 255;
  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      _name.text.trim().length <= 20 &&
      _emailValid &&
      _passwordValid &&
      _password.text == _confirmation.text &&
      _agreed &&
      !_isBusy;

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showTerms() async {
    final agreed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _TermsSheet(),
    );
    if (mounted && agreed == true) setState(() => _agreed = true);
  }

  Future<void> _submit() async {
    if (_isBusy || !_form.currentState!.validate() || !_agreed) {
      return;
    }
    final repository = AppScope.of(context).auth.repository;
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final user = await repository.signup(
        email: _email.text,
        password: _password.text,
        name: _name.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            initialEmail: user.email,
            notice: AuthStrings.signupDone,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.status == 409
              ? AuthStrings.emailConflict
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
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: AppColors.scheme,
        scaffoldBackgroundColor: Colors.white,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white,
        ),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            foregroundColor: _ink,
            centerTitle: false,
            titleSpacing: 0,
            leading: IconButton(
              tooltip: '뒤로',
              icon: const Icon(Icons.chevron_left, size: 28),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text(
              '회원가입',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        _field(
                          label: '이름',
                          controller: _name,
                          hint: '이름을 입력해 주세요',
                          autofillHints: const [AutofillHints.name],
                          validator: (value) => value!.trim().isEmpty
                              ? '이름을 입력해 주세요.'
                              : value.trim().length > 20
                              ? '이름은 20자 이내로 입력해 주세요.'
                              : null,
                        ),
                        _field(
                          label: '이메일',
                          controller: _email,
                          hint: '이메일을 입력해 주세요',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: (value) =>
                              _emailValid ? null : '올바른 이메일 주소를 입력해 주세요.',
                        ),
                        _field(
                          label: '비밀번호',
                          controller: _password,
                          hint: '비밀번호를 입력해 주세요',
                          helper: '영문·숫자 포함 8자 이상',
                          obscure: _hidePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          suffix: IconButton(
                            tooltip: _hidePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                          validator: (value) => _passwordValid
                              ? null
                              : '영문·숫자를 포함해 8자 이상 입력해 주세요.',
                        ),
                        _field(
                          label: '비밀번호 확인',
                          controller: _confirmation,
                          hint: '비밀번호를 다시 입력해 주세요',
                          obscure: _hideConfirmation,
                          action: TextInputAction.done,
                          suffix: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_passwordValid &&
                                  _confirmation.text == _password.text)
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                              IconButton(
                                tooltip: _hideConfirmation
                                    ? '확인 비밀번호 보기'
                                    : '확인 비밀번호 숨기기',
                                icon: Icon(
                                  _hideConfirmation
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _hideConfirmation = !_hideConfirmation,
                                ),
                              ),
                            ],
                          ),
                          validator: (value) =>
                              value == _password.text && value!.isNotEmpty
                              ? null
                              : '비밀번호가 일치하지 않아요.',
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 40,
                              child: Checkbox(
                                value: _agreed,
                                activeColor: _primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                onChanged: (value) =>
                                    setState(() => _agreed = value!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton(
                                onPressed: _showTerms,
                                style: TextButton.styleFrom(
                                  foregroundColor: _ink,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  '(필수) 이용약관·개인정보 수집 동의',
                                  style: TextStyle(
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _showTerms,
                              tooltip: '약관 전문 보기',
                              icon: const Icon(
                                Icons.chevron_right,
                                color: _muted,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.background)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                14,
                24,
                14 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 432),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _ready ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        disabledBackgroundColor: AppColors.disabled,
                        disabledForegroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(_isBusy ? AuthStrings.saving : '가입하고 시작하기'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required FormFieldValidator<String> validator,
    String? helper,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    List<String>? autofillHints,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                ),
              ],
            ),
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            enabled: !_isBusy,
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: action,
            autofillHints: autofillHints,
            autocorrect:
                keyboardType != TextInputType.emailAddress &&
                !obscure &&
                label == '이름',
            enableSuggestions: label == '이름',
            style: const TextStyle(fontSize: 15, color: _ink),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (_) => setState(() {}),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              helperText: helper,
              suffixIcon: suffix,
              hintStyle: const TextStyle(fontSize: 14, color: AppColors.muted),
              helperStyle: const TextStyle(fontSize: 12, color: _muted),
              errorMaxLines: 2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '약관 전문',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const TabBar(
              labelColor: _ink,
              unselectedLabelColor: _muted,
              indicatorColor: _ink,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: '이용약관'),
                Tab(text: '개인정보 수집·이용'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _termsContent([
                    (
                      '제1조 (목적)',
                      '이 약관은 Backpack이 제공하는 그룹 여행 일정·경비 관리 기능의 이용 조건과 절차를 정합니다.',
                    ),
                    (
                      '제2조 (회원과 게스트)',
                      '회원은 이메일로 가입한 이용자를, 게스트는 초대 코드와 이름만으로 여행에 참여한 이용자를 말합니다. 게스트는 조회와 투표 기능을 사용할 수 있습니다.',
                    ),
                    (
                      '제3조 (여행 정보의 공유)',
                      '여행에 등록한 일정·지출·준비 항목은 같은 여행의 참여자에게 공개됩니다. 여행 참여자가 아닌 사람은 볼 수 없습니다.',
                    ),
                    (
                      '제4조 (정산 결과)',
                      '서비스가 계산한 정산 금액은 참고용이며, 실제 송금은 서비스 밖에서 이루어집니다.',
                    ),
                  ]),
                  _termsContent([
                    (
                      '회원 가입',
                      '수집: 이름, 이메일, 비밀번호(암호화 저장)\n목적: 회원 식별, 참여자 이름 표시\n보유 기간: 회원 탈퇴 시까지',
                    ),
                    (
                      '게스트 참여',
                      '수집: 이름, 기기 식별 토큰\n목적: 여행 참여자 식별\n보유 기간: 여행 삭제 시까지',
                    ),
                    (
                      '영수증 등록',
                      '수집: 영수증 사진, 인식된 항목·금액\n목적: 지출 입력·정산\n보유 기간: 지출 삭제 시까지',
                    ),
                    (
                      'AI 일정 재구성',
                      '수집: 현재 위치(요청할 때만)\n목적: 다음 활동 추천\n보유 기간: 추천 후 바로 삭제',
                    ),
                  ]),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('동의하고 닫기'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _termsContent(List<(String, String)> sections) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        '화면 시안용 예시 · 실제 약관은 서비스 출시 전 확정됩니다.',
        style: TextStyle(color: _muted, fontSize: 12),
      ),
      const SizedBox(height: 20),
      for (final section in sections) ...[
        Text(
          section.$1,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          section.$2,
          style: const TextStyle(fontSize: 13, height: 1.65, color: _muted),
        ),
        const SizedBox(height: 22),
      ],
    ],
  );
}
