import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/destinations.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../expense/data/expense_models.dart';
import '../data/trip_models.dart';
import 'invite_sheet.dart';

/// BP-TR-002 여행 만들기 → 생성 완료(초대 코드)
///
/// [initial]이 있으면 여행 수정 화면으로 쓴다 (방장만).
class TripCreateScreen extends StatefulWidget {
  const TripCreateScreen({super.key, this.initial});

  final TripDetail? initial;

  @override
  State<TripCreateScreen> createState() => _TripCreateScreenState();
}

class _TripCreateScreenState extends State<TripCreateScreen> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _destination = TextEditingController(
    text: widget.initial?.destination,
  );
  late DestinationPreset _preset = widget.initial == null
      ? destinationPresets.first
      : presetFor(widget.initial!.currencyCode, widget.initial!.timeZone);
  late DateTimeRange? _dates = widget.initial == null
      ? null
      : DateTimeRange(
          start: widget.initial!.startDate,
          end: widget.initial!.endDate,
        );
  Future<ExchangeRate?>? _rate;
  bool _busy = false;
  Map<String, String> _errors = {};

  bool get _editing => widget.initial != null;

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      _destination.text.trim().isNotEmpty &&
      _dates != null &&
      !_busy;

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  @override
  void dispose() {
    _name.dispose();
    _destination.dispose();
    super.dispose();
  }

  void _loadRate() {
    _rate = _preset.currencyCode == 'KRW'
        ? Future.value(null)
        : services.expenses
              .rate(_preset.currencyCode)
              .then<ExchangeRate?>((rate) => rate)
              .catchError((Object _) => null);
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _dates,
      helpText: '여행 기간',
      saveText: '선택',
    );
    if (picked != null) {
      setState(() => _dates = picked);
    }
  }

  Future<void> _pickDestination() async {
    final picked = await showAppSheet<DestinationPreset>(
      context,
      title: '여행 지역',
      child: Column(
        children: [
          for (final preset in destinationPresets)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(preset.label),
              subtitle: Text('${preset.currencyName} (${preset.currencyCode})'),
              trailing: preset == _preset
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, preset),
            ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _preset = picked;
        _loadRate();
      });
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      final dates = _dates!;
      if (_editing) {
        final initial = widget.initial!;
        await services.trips.update(
          initial.id,
          name: _name.text.trim(),
          destination: _destination.text.trim(),
          startDate: dates.start,
          endDate: dates.end,
          currencyCode: _preset.currencyCode == initial.currencyCode
              ? null
              : _preset.currencyCode,
          timeZone: _preset.timeZone,
        );
        if (mounted) {
          Navigator.pop(context, initial.id);
        }
        return;
      }
      final trip = await services.trips.create(
        name: _name.text.trim(),
        destination: _destination.text.trim(),
        startDate: dates.start,
        endDate: dates.end,
        currencyCode: _preset.currencyCode,
        timeZone: _preset.timeZone,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _TripCreatedScreen(trip: trip)),
      );
      if (mounted) {
        Navigator.pop(context, trip.id);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.code == 'TRIP_PERIOD_CONFLICT') {
        showSnack(
          context,
          '바꿀 기간 밖에 일정이 ${e.details['scheduleCount'] ?? ''}개 있어요. 일정을 먼저 옮겨 주세요.',
        );
      } else if (e.details.isNotEmpty) {
        setState(() => _errors = e.details);
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = _dates;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_editing ? '여행 정보 수정' : '여행 만들기'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const FieldLabel('여행 이름', required: true),
          TextField(
            controller: _name,
            maxLength: 50,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: '예: 오사카 먹방 여행',
              counterText: '',
              errorText: _errors['name'],
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          const FieldLabel('지역 · 통화', required: true),
          _PickerTile(
            icon: Icons.public,
            text:
                '${_preset.label} · ${_preset.currencyName} ${_preset.currencyCode}',
            onTap: _pickDestination,
          ),
          FutureBuilder<ExchangeRate?>(
            future: _rate,
            builder: (context, snapshot) {
              final rate = snapshot.data;
              if (_preset.currencyCode == 'KRW') {
                return const SizedBox.shrink();
              }
              final text = rate == null
                  ? (snapshot.connectionState == ConnectionState.done
                        ? '오늘 환율을 아직 불러오지 못했어요'
                        : '오늘 환율을 불러오는 중…')
                  : '오늘 환율 ${rate.unit}${_preset.currencyCode} = '
                        '${Fmt.number(rate.unitRateToKrw)}원 · ${Fmt.monthDay(rate.rateDate)} 기준';
              return Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const FieldLabel('여행지', required: true),
          TextField(
            controller: _destination,
            maxLength: 100,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '예: 일본 오사카',
              counterText: '',
              errorText: _errors['destination'],
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          const FieldLabel('여행 기간', required: true),
          _PickerTile(
            icon: Icons.calendar_month_outlined,
            text: dates == null
                ? '날짜를 선택해 주세요'
                : '${Fmt.shortDate(dates.start)} – ${Fmt.shortDate(dates.end)}'
                      ' · ${dates.duration.inDays}박 ${dates.duration.inDays + 1}일',
            muted: dates == null,
            onTap: _pickDates,
          ),
          if (_errors['endDate'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                _errors['endDate']!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          if (_editing && _preset.currencyCode != widget.initial!.currencyCode)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                '지출이 등록된 여행은 통화를 바꿀 수 없어요.',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: _ready ? _submit : null,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_editing ? '저장' : '여행 만들기'),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.text,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    color: muted ? AppColors.muted : AppColors.ink,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// BP-TR-002 생성 완료
class _TripCreatedScreen extends StatelessWidget {
  const _TripCreatedScreen({required this.trip});

  final TripDetail trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.celebration_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 18),
              Text(
                '${trip.name}\n여행을 만들었어요',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${trip.destination} · ${Fmt.range(trip.startDate, trip.endDate)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 32),
              InviteCodeCard(trip: trip),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('여행 시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
