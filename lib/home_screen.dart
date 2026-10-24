import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'features/expense/presentation/expense_split_screen.dart';

const _primary = AppColors.primary;
const _ink = AppColors.ink;
const _muted = AppColors.muted;
const _surface = AppColors.background;

/// Frontend preview data. No account, payment or AI request is sent.
class TravelHomeScreen extends StatefulWidget {
  const TravelHomeScreen({super.key});

  @override
  State<TravelHomeScreen> createState() => _TravelHomeScreenState();
}

class _TravelHomeScreenState extends State<TravelHomeScreen> {
  int _tab = 0;
  bool _replanned = false;
  bool _recorded = false;
  bool _read = false;
  final _packed = <int>{0, 1};

  Future<void> _sheet(String title, Widget content) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(colorScheme: AppColors.scheme),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  content,
                ],
              ),
            ),
          ),
        ),
      );

  void _trips() => _sheet(
    '여행 전환',
    Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('참여 중인 여행 1개', style: TextStyle(color: _muted)),
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined, color: _primary),
            title: const Text(
              '오사카 4박 5일',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('10.02 – 10.06 · 여행 중 · 방장'),
            trailing: const Icon(Icons.check, color: _primary),
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '샘플 여행을 둘러보고 있어요.',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
      ],
    ),
  );

  void _notifications() {
    setState(() => _read = true);
    _sheet(
      '알림',
      Column(
        children: [
          _notice(
            Icons.auto_awesome,
            '2일차 오후 일정을 확인해 보세요',
            '고정된 예약에 맞춰 남은 일정을 조정할 수 있어요.',
          ),
          _notice(
            Icons.receipt_long_outlined,
            '지출이 등록됐어요',
            '이치란 라멘 난바점 · ¥7,360',
          ),
          _notice(
            Icons.checklist,
            '여행 준비를 확인해 보세요',
            '준비물 4개 중 ${_packed.length}개 완료',
          ),
        ],
      ),
    );
  }

  Widget _notice(IconData icon, String title, String text) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _primary),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
    subtitle: Text(text, style: const TextStyle(fontSize: 12, height: 1.5)),
  );

  void _record() => _sheet(
    '활동 기록',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '구로몬 시장',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('14:15 시작 · 난바 · 현재 활동', style: TextStyle(color: _muted)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {
            setState(() => _recorded = true);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.check),
          label: const Text('활동 완료로 기록'),
        ),
      ],
    ),
  );

  void _replan() => _sheet(
    '남은 일정을 다시 짤까요?',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '우메다 스카이빌딩 17:30 예약은 유지하고, 쇼핑 시간을 줄여 여유롭게 이동하는 일정이에요.',
          style: TextStyle(height: 1.7, color: _muted),
        ),
        const SizedBox(height: 20),
        const Text(
          '15:15  신사이바시 쇼핑\n16:40  우메다로 이동\n17:30  우메다 스카이빌딩',
          style: TextStyle(height: 2, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        const Text(
          '샘플 추천 일정입니다. 실제 AI 호출은 하지 않아요.',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            setState(() => _replanned = true);
            Navigator.pop(context);
          },
          child: const Text('추천 일정 적용'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: AppColors.scheme,
        scaffoldBackgroundColor: _surface,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _tab == 0
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
        child: Scaffold(
          body: SafeArea(
            top: _tab != 0,
            bottom: false,
            child: _tab == 0 ? _home() : _section(),
          ),
          bottomNavigationBar: NavigationBar(
            height: 72,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppColors.primarySoft,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.muted,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() => _tab = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: _primary),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month, color: _primary),
                label: '일정',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(
                  Icons.account_balance_wallet,
                  color: _primary,
                ),
                label: '경비',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist, color: _primary),
                label: '준비',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _home() => SingleChildScrollView(
    child: Column(
      children: [
        Container(
          decoration: const BoxDecoration(gradient: AppColors.coverGradient),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _trips,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            alignment: Alignment.centerLeft,
                          ),
                          child: const Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              Text(
                                '오사카 4박 5일',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '여행 초대',
                        onPressed: () => _sheet(
                          '함께 여행할 친구 초대',
                          Column(
                            children: [
                              const Text(
                                '샘플 초대 코드',
                                style: TextStyle(color: _muted),
                              ),
                              const SizedBox(height: 12),
                              const SelectableText(
                                'OSAKA26',
                                style: TextStyle(
                                  fontSize: 30,
                                  letterSpacing: 5,
                                  color: _primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    const ClipboardData(text: 'OSAKA26'),
                                  );
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('샘플 초대 코드를 복사했어요.'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('코드 복사'),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '미리보기 코드로 실제 여행에는 참여할 수 없어요.',
                                style: TextStyle(color: _muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      IconButton(
                        tooltip: '알림',
                        onPressed: _notifications,
                        icon: Badge(
                          isLabelVisible: !_read,
                          child: const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DAY 2 · 10.03 토',
                              style: TextStyle(
                                color: AppColors.coverText,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '여행 2일차',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Icon(
                                  Icons.wb_sunny_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                Text(
                                  '23°',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 3,
                          children: [
                            for (final name in ['배', '김', '윤', '박'])
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: Colors.white.withValues(
                                  alpha: .22,
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                const SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: CustomPaint(painter: _SkylinePainter()),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _pill(
                              _recorded ? '✓ 완료' : '● 지금',
                              _primary,
                              AppColors.primarySoft,
                            ),
                            const Spacer(),
                            const Text(
                              '14:15부터 · 35분째',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '구로몬 시장',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: _muted,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '난바 · 현재 위치',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 16),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '17:30 우메다 스카이빌딩',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '2:40',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '남음',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: const LinearProgressIndicator(
                                  value: .38,
                                  minHeight: 4,
                                  color: _ink,
                                  backgroundColor: AppColors.border,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _replanned
                                ? AppColors.successSoft
                                : AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _replanned
                                    ? Icons.check_circle_outline
                                    : Icons.schedule,
                                size: 16,
                                color: _replanned
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _replanned
                                      ? '추천 일정을 적용했어요. 예약 시간에 맞춰 출발해요.'
                                      : '일정이 45분 늦어졌어요. 남은 일정을 다시 짜 볼까요?',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: _record,
                                icon: Icon(
                                  _recorded
                                      ? Icons.check_circle
                                      : Icons.task_alt,
                                  size: 18,
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: _surface,
                                  foregroundColor: _ink,
                                  minimumSize: const Size(0, 46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                label: Text(
                                  _recorded ? '기록 완료' : '활동 기록',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _replan,
                                icon: const Icon(Icons.auto_awesome, size: 17),
                                label: const Text(
                                  'AI로 다시 짜기',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '오늘 남은 일정',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _tab = 1),
                              child: const Text(
                                '일정 전체 ›',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        _event(
                          '5',
                          _replanned ? '15:15' : '15:00',
                          '신사이바시 쇼핑',
                          '지하철 15분',
                        ),
                        _event(
                          '⌑',
                          '17:30',
                          '우메다 스카이빌딩',
                          '예약 확정 · 시간 고정',
                          locked: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '공동 지출 · 예산 59%',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 24,
                          runSpacing: 8,
                          children: [
                            Text(
                              '₩1,180,064',
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '내 정산 +₩737,600',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: .59,
                            minHeight: 5,
                            backgroundColor: _surface,
                            color: _primary,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() => _tab = 2),
                            child: const Text(
                              '경비·정산 보기 ›',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '샘플 여행 미리보기 · 데이터는 저장되지 않아요',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _section() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ['홈', '일정', '경비', '준비'][_tab],
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(onPressed: _trips, child: const Text('오사카 ▾')),
              ],
            ),
            const SizedBox(height: 16),
            if (_tab == 1) ...[
              const Text(
                'DAY 2 · 10.03 토 · 맑음 23°',
                style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _card(
                Column(
                  children: [
                    _event('✓', '09:30', '오사카성 공원', '완료'),
                    _event('✓', '12:00', '이치란 라멘 난바점', '완료'),
                    _event(
                      '3',
                      '14:15',
                      '구로몬 시장',
                      _recorded ? '활동 완료' : '현재 활동',
                    ),
                    _event(
                      '5',
                      _replanned ? '15:15' : '15:00',
                      '신사이바시 쇼핑',
                      '쇼핑',
                    ),
                    _event('⌑', '17:30', '우메다 스카이빌딩', '예약 확정', locked: true),
                  ],
                ),
              ),
            ],
            if (_tab == 2) ...[
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ExpenseSplitScreen(),
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.call_split),
                label: const Text(
                  '항목별 경비 나누기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              _card(
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('여행 공동 지출', style: TextStyle(color: _muted)),
                    SizedBox(height: 10),
                    Text(
                      '₩1,180,064',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '전체 예산 ₩2,000,000 · 59% 사용',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                Column(
                  children: [
                    _notice(
                      Icons.restaurant_outlined,
                      '이치란 라멘 난바점',
                      '¥7,360 · 5명 나누기',
                    ),
                    _notice(
                      Icons.local_activity_outlined,
                      '우메다 스카이빌딩 입장권',
                      '¥10,000 · 5명 나누기',
                    ),
                  ],
                ),
              ),
            ],
            if (_tab == 3)
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '여행 준비 ${_packed.length}/4',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0; i < 4; i++)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          ['여권 챙기기', '항공권 확인', '여행자 보험 가입', '보조 배터리 챙기기'][i],
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: _packed.contains(i),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _packed.add(i);
                          } else {
                            _packed.remove(i);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              '샘플 데이터로 구성된 미리보기입니다.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _card(Widget child) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );

  Widget _pill(String text, Color color, Color background) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );

  Widget _event(
    String marker,
    String time,
    String title,
    String subtitle, {
    bool locked = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: locked ? _ink : AppColors.dayTwo,
          child: locked
              ? const Icon(Icons.lock_outline, size: 14, color: Colors.white)
              : Text(
                  marker,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
        ),
        const SizedBox(width: 10),
        Text(
          time,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: .22);
    const heights = [
      .3,
      .7,
      .45,
      .9,
      .55,
      .35,
      .8,
      .5,
      1.0,
      .4,
      .65,
      .3,
      .75,
      .5,
      .9,
      .4,
    ];
    final width = size.width / heights.length;
    for (int i = 0; i < heights.length; i++) {
      final top = size.height * (1 - heights[i]);
      canvas.drawRect(
        Rect.fromLTWH(i * width, top, width * .68, size.height - top),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) => false;
}
