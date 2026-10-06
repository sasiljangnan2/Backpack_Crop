import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';

void main() => runApp(const MyApp());

@Preview(name: 'Backpack 시작 화면', size: Size(390, 844))
Widget welcomePreview() => const MyApp();

const _brand = Color(0xFF007F9F);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backpack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: _brand),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _showPreview(BuildContext context, String action) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$action 기능은 준비 중이에요.')));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
                                    color: _brand,
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
                                    color: Color(0xFF202020),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '일정부터 정산까지, 함께 가는 여행',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF656565),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                const _Feature(
                                  icon: Icons.auto_awesome_outlined,
                                  text: '늦어진 일정은 AI가 남은 일정을 다시 짜 줘요',
                                ),
                                const SizedBox(height: 14),
                                const _Feature(
                                  icon: Icons.receipt_long_outlined,
                                  text: '영수증을 찍으면 항목별로 나눠 정산해요',
                                ),
                                const SizedBox(height: 14),
                                const _Feature(
                                  icon: Icons.currency_exchange_rounded,
                                  text: '환율을 반영해 예산과 1인 준비 금액을 계산해요',
                                ),
                                const SizedBox(height: 48),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () =>
                                        _showPreview(context, '로그인'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _brand,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(54),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    child: const Text('로그인'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _showPreview(context, '회원가입'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF242424),
                                      minimumSize: const Size.fromHeight(54),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E6E8),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    child: const Text('회원가입'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _showPreview(context, '초대 코드로 게스트 참여'),
                                    icon: const Icon(
                                      Icons.confirmation_number_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('초대 코드로 게스트 참여'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _brand,
                                      minimumSize: const Size(0, 48),
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const Center(
                                  child: Text(
                                    '가입 없이 이름만으로 일정 확인·투표에 참여할 수 있어요',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.5,
                                      color: Color(0xFF858585),
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
            color: const Color(0xFFE8F5F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _brand, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }
}
