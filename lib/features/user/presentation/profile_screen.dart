import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../data/user_models.dart';

/// 내 정보: 이름 · 비밀번호 · 알림 설정 · 로그아웃 · 탈퇴
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user = services.auth.user;

  @override
  void initState() {
    super.initState();
    services.auth.refreshUser().then((user) {
      if (mounted) {
        setState(() => _user = user);
      }
    });
  }

  Future<void> _changeName() async {
    final controller = TextEditingController(text: _user?.name);
    final name = await showAppSheet<String>(
      context,
      title: '이름 바꾸기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: controller, autofocus: true, maxLength: 20),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    try {
      final user = await services.users.changeName(name);
      services.auth.updateUser(user);
      setState(() => _user = user);
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _changePassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _PasswordSheet(),
    );
  }

  Future<void> _toggle({
    bool? schedule,
    bool? expense,
    bool? settlement,
  }) async {
    try {
      final user = await services.users.changeNotificationSettings(
        schedule: schedule,
        expense: expense,
        settlement: settlement,
      );
      services.auth.updateUser(user);
      if (mounted) {
        setState(() => _user = user);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _logout() async {
    final ok = await confirm(context, title: '로그아웃할까요?', confirmLabel: '로그아웃');
    if (ok) {
      await services.auth.logout();
    }
  }

  Future<void> _withdraw() async {
    final controller = TextEditingController();
    final password = await showAppSheet<String>(
      context,
      title: '탈퇴',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '참여 중인 여행에서 모두 나가고, 방장인 여행은 다음 멤버에게 넘어가요. '
            '함께 기록한 지출과 정산은 여행에 남아요. 되돌릴 수 없어요.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(hintText: '비밀번호를 입력해 주세요'),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (password == null || password.isEmpty || !mounted) {
      return;
    }
    try {
      await services.users.withdraw(password);
      await services.auth.forceSignOut();
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(
          context,
          e.code == 'INVALID_PASSWORD' ? '비밀번호가 맞지 않아요.' : e.displayMessage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                MemberAvatar(user?.name ?? '?', radius: 26, highlight: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: _changeName, child: const Text('이름 변경')),
              ],
            ),
          ),
          const SectionTitle('알림'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  value: user?.notifySchedule ?? true,
                  onChanged: user == null ? null : (v) => _toggle(schedule: v),
                  title: const Text('일정 · 투표 · 준비'),
                  subtitle: const Text(
                    '일정이 바뀌거나 투표가 열리면',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                SwitchListTile(
                  value: user?.notifyExpense ?? true,
                  onChanged: user == null ? null : (v) => _toggle(expense: v),
                  title: const Text('지출'),
                  subtitle: const Text(
                    '누군가 지출을 등록하면',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                SwitchListTile(
                  value: user?.notifySettlement ?? true,
                  onChanged: user == null
                      ? null
                      : (v) => _toggle(settlement: v),
                  title: const Text('정산'),
                  subtitle: const Text(
                    '정산 결과가 공유되면',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (!AppConfig.pushEnabled)
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                '이 빌드에는 푸시 알림이 꺼져 있어요. 알림은 알림함에서 확인할 수 있어요.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          const SectionTitle('계정'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('비밀번호 변경'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePassword,
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('로그아웃'),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _withdraw,
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('회원 탈퇴'),
          ),
          const SizedBox(height: 8),
          const Text(
            '환율 정보: 한국수출입은행 · 유럽중앙은행(Frankfurter) · ExchangeRate-API',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;
  bool _busy = false;

  bool get _valid =>
      _next.text.length >= 8 &&
      RegExp('[A-Za-z]').hasMatch(_next.text) &&
      RegExp('[0-9]').hasMatch(_next.text);

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await services.users.changePassword(
        _current.text,
        _next.text,
      );
      await services.auth.applyTokens(result);
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, '비밀번호를 바꿨어요. 다른 기기에서는 다시 로그인해야 해요.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.displayMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '비밀번호 변경',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(hintText: '현재 비밀번호'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _next,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '새 비밀번호',
                  helperText: '영문·숫자 포함 8자 이상',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _valid && _current.text.isNotEmpty && !_busy
                    ? _save
                    : null,
                child: const Text('변경'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
