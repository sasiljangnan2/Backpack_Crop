import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// BP-AU-001 시작 화면
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topSpace = (constraints.maxHeight * .10).clamp(24.0, 80.0);
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: topSpace),
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.backpack_outlined,
                                    size: 36,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Backpack',
                                  style: TextStyle(
                                    fontSize: 32,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.2,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '일정부터 정산까지, 함께 가는 여행',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                const _Feature(
                                  icon: Icons.schedule_rounded,
                                  text: '일정이 늦어지면 다음 고정 일정까지 남은 시간을 알려 줘요',
                                ),
                                const SizedBox(height: 14),
                                const _Feature(
                                  icon: Icons.receipt_long_outlined,
                                  text: '누가 냈는지만 기록하면 정산과 송금 경로를 자동으로 계산해요',
                                ),
                                const SizedBox(height: 14),
                                const _Feature(
                                  icon: Icons.currency_exchange_rounded,
                                  text: '환율을 반영해 예산과 1인 준비 금액을 계산해요',
                                ),
                                const SizedBox(height: 48),
                                const Spacer(),
                                FilledButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  ),
                                  child: const Text('로그인'),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  ),
                                  child: const Text('회원가입'),
                                ),
                                const SizedBox(height: 16),
                                const Center(
                                  child: Text(
                                    '초대 코드를 받았다면 가입 후 여행 목록에서 참여할 수 있어요',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 26),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
