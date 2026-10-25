import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../trip/data/trip_models.dart';
import '../data/expense_models.dart';

/// BP-EX-003 지출 입력 ① 항목 확인 → BP-EX-004 ② 분담 → 등록 완료.
/// [existing]이 있으면 수정 화면이다 (항목·분담을 통째로 바꾼다).
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, required this.trip, this.existing});

  final TripDetail trip;
  final ExpenseDetail? existing;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ItemState {
  _ItemState({String name = '', String amount = '', Set<String>? members})
    : name = TextEditingController(text: name),
      amount = TextEditingController(text: amount),
      members = members ?? {};

  final TextEditingController name;
  final TextEditingController amount;
  final Set<String> members;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _manualRate = TextEditingController();
  late ExpenseCategory _category = ExpenseCategory.food;
  late String _payerId = widget.trip.myMemberId;
  late DateTime _paidDate = _defaultDate();
  late bool _krw = widget.trip.isKrwTrip;
  RateMode _foreignMode = RateMode.api;
  int _step = 0;
  bool _busy = false;

  SplitMethod _split = SplitMethod.equal;
  late Set<String> _equalMembers = {
    for (final m in widget.trip.members) m.memberId,
  };
  final List<_ItemState> _items = [];
  final Map<String, TextEditingController> _custom = {};

  Future<ExchangeRate?>? _rate;
  ExpenseDetail? _preview;
  String? _previewError;
  bool _previewing = false;
  Timer? _debounce;
  int _previewSeq = 0;

  TripDetail get trip => widget.trip;
  bool get _editing => widget.existing != null;
  RateMode get _rateMode => _krw ? RateMode.krw : _foreignMode;
  String get _currency => _krw ? 'KRW' : trip.currencyCode;
  TripMember get _payer => trip.members.firstWhere(
    (m) => m.memberId == _payerId,
    orElse: () => trip.me,
  );

  DateTime _defaultDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(trip.startDate)) {
      return today;
    }
    return today.isAfter(trip.endDate) ? trip.endDate : today;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _category = existing.category;
      _payerId = existing.payer.memberId;
      _paidDate = existing.paidDate;
      _krw = existing.rateMode == RateMode.krw;
      if (!_krw) {
        _foreignMode = existing.rateMode;
        _amount.text = Fmt.number(existing.amountLocal ?? 0)
            .replaceAll(',', '');
        if (existing.rateMode == RateMode.manual &&
            existing.appliedRate != null) {
          _manualRate.text = existing.appliedRate!.toString();
        }
      } else {
        _amount.text = existing.amountKrw.toString();
      }
      _split = existing.splitMethod;
      switch (existing.splitMethod) {
        case SplitMethod.equal:
          _equalMembers = {
            for (final s in existing.items.first.members) s.memberId,
          };
        case SplitMethod.item:
          for (final item in existing.items) {
            _items.add(
              _ItemState(
                name: item.name,
                amount: _krw
                    ? item.amountKrw.toString()
                    : Fmt.number(item.amountLocal ?? 0).replaceAll(',', ''),
                members: {for (final s in item.members) s.memberId},
              ),
            );
          }
        case SplitMethod.custom:
          for (final share in existing.items.first.members) {
            _custom[share.memberId] = TextEditingController(
              text: share.shareKrw.toString(),
            );
          }
      }
    }
    _refreshRate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _amount.dispose();
    _manualRate.dispose();
    for (final item in _items) {
      item.dispose();
    }
    for (final c in _custom.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.replaceAll(',', '').trim());

  void _refreshRate() {
    if (_krw || _foreignMode != RateMode.api) {
      _rate = null;
      return;
    }
    _rate = services.expenses
        .rate(trip.currencyCode, date: _paidDate)
        .then<ExchangeRate?>((rate) => rate)
        .catchError((Object _) => null);
  }

  double? get _effectiveRate {
    if (_krw) {
      return 1;
    }
    return switch (_foreignMode) {
      RateMode.prepaid => _payer.prepaidRate,
      RateMode.manual => _parse(_manualRate.text),
      _ => null,
    };
  }

  bool get _stepOneReady {
    final amount = _parse(_amount.text);
    if (_title.text.trim().isEmpty || amount == null || amount <= 0) {
      return false;
    }
    if (!_krw &&
        _foreignMode == RateMode.manual &&
        (_parse(_manualRate.text) ?? 0) <= 0) {
      return false;
    }
    if (!_krw &&
        _foreignMode == RateMode.prepaid &&
        _payer.prepaidRate == null) {
      return false;
    }
    return true;
  }

  ExpenseDraft _draft() {
    final amount = _parse(_amount.text) ?? 0;
    final draft = ExpenseDraft(
      payerMemberId: _payerId,
      title: _title.text.trim(),
      category: _category,
      paidDate: _paidDate,
      rateMode: _rateMode,
      splitMethod: _split,
      amountLocal: _krw ? null : amount,
      amountKrw: _krw ? amount.round() : null,
      manualRate: _foreignMode == RateMode.manual
          ? _parse(_manualRate.text)
          : null,
      version: widget.existing?.version,
    );
    switch (_split) {
      case SplitMethod.equal:
        draft.memberIds = [
          for (final m in trip.members)
            if (_equalMembers.contains(m.memberId)) m.memberId,
        ];
      case SplitMethod.item:
        draft.items = [
          for (final item in _items)
            ExpenseItemDraft(
              name: item.name.text,
              amount: _parse(item.amount.text),
              members: {for (final id in item.members) id: null},
            ),
        ];
      case SplitMethod.custom:
        draft.items = [
          ExpenseItemDraft(
            members: {
              for (final entry in _custom.entries)
                if ((_parse(entry.value.text) ?? 0) > 0)
                  entry.key: _parse(entry.value.text)!.round(),
            },
          ),
        ];
    }
    return draft;
  }

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runPreview);
  }

  Future<void> _runPreview() async {
    final seq = ++_previewSeq;
    setState(() => _previewing = true);
    try {
      final preview = await services.expenses.preview(trip.id, _draft());
      if (!mounted || seq != _previewSeq) {
        return;
      }
      setState(() {
        _preview = preview;
        _previewError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _previewSeq) {
        return;
      }
      setState(() => _previewError = _messageOf(e));
    } finally {
      if (mounted && seq == _previewSeq) {
        setState(() => _previewing = false);
      }
    }
  }

  String _messageOf(ApiException e) => switch (e.code) {
    'EXCHANGE_RATE_NOT_FOUND' => '이 날짜의 환율을 찾지 못했어요. "직접 입력" 환율을 써 주세요.',
    'PREPAID_RATE_NOT_SET' => '${_payer.name}님의 선불 환율이 없어요. 여행 설정에서 넣어 주세요.',
    _ => e.displayMessage,
  };

  Future<void> _next() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      // 금액·환율이 맞는지 먼저 서버 계산으로 확인한다 (균등 분담으로 미리보기)
      final check = ExpenseDraft(
        payerMemberId: _payerId,
        title: _title.text.trim(),
        category: _category,
        paidDate: _paidDate,
        rateMode: _rateMode,
        splitMethod: SplitMethod.equal,
        amountLocal: _krw ? null : _parse(_amount.text),
        amountKrw: _krw ? _parse(_amount.text)!.round() : null,
        manualRate: _foreignMode == RateMode.manual
            ? _parse(_manualRate.text)
            : null,
        memberIds: [trip.myMemberId],
      );
      final base = await services.expenses.preview(trip.id, check);
      if (!mounted) {
        return;
      }
      if (_items.isEmpty) {
        _items.add(
          _ItemState(members: {for (final m in trip.members) m.memberId}),
        );
      }
      for (final m in trip.members) {
        _custom.putIfAbsent(m.memberId, TextEditingController.new);
      }
      setState(() {
        _step = 1;
        _preview = base;
      });
      _schedulePreview();
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, _messageOf(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final draft = _draft();
      final existing = widget.existing;
      final saved = existing == null
          ? await services.expenses.create(trip.id, draft)
          : await services.expenses.update(trip.id, existing.id!, draft);
      if (!mounted) {
        return;
      }
      if (_editing) {
        Navigator.pop(context, saved);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ExpenseDoneScreen(trip: trip, expense: saved),
        ),
      );
      if (mounted) {
        Navigator.pop(context, saved);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.code == 'VERSION_CONFLICT') {
        showSnack(context, e.message);
        Navigator.pop(context);
        return;
      }
      setState(() => _previewError = _messageOf(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _step = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(_editing ? '지출 수정' : '지출 등록'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: _step == 0 ? .5 : 1,
              minHeight: 3,
              backgroundColor: AppColors.background,
            ),
          ),
        ),
        body: _step == 0 ? _stepOne() : _stepTwo(),
        bottomNavigationBar: BottomActionBar(
          child: _step == 0
              ? FilledButton(
                  onPressed: _stepOneReady && !_busy ? _next : null,
                  child: _busy ? _spinner() : const Text('다음 · 나누기'),
                )
              : FilledButton(
                  onPressed:
                      _preview != null &&
                          _previewError == null &&
                          !_previewing &&
                          !_busy
                      ? _submit
                      : null,
                  child: _busy ? _spinner() : Text(_editing ? '저장' : '등록'),
                ),
        ),
      ),
    );
  }

  Widget _spinner() => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );

  // ---- ① 항목 확인

  Widget _stepOne() {
    final amount = _parse(_amount.text);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        const Text(
          '결제 정보',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        const FieldLabel('내용', required: true),
        TextField(
          controller: _title,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: '예: 이치란 라멘',
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        const FieldLabel('결제자', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final member in trip.members)
              ChoiceChip(
                selected: member.memberId == _payerId,
                showCheckmark: false,
                avatar: MemberAvatar(member.name, radius: 10),
                label: Text(member.isMe ? '${member.name} (나)' : member.name),
                onSelected: (_) => setState(() => _payerId = member.memberId),
              ),
          ],
        ),
        if (_payerId != trip.myMemberId)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '다른 사람이 낸 지출을 대신 입력해요',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        const SizedBox(height: 14),
        const FieldLabel('분류', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in ExpenseCategory.values)
              ChoiceChip(
                selected: category == _category,
                showCheckmark: false,
                avatar: Icon(category.icon, size: 16),
                label: Text(category.label),
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('결제 날짜', required: true),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: trip.startDate.subtract(const Duration(days: 120)),
              lastDate: trip.endDate.add(const Duration(days: 60)),
              initialDate: _paidDate,
              helpText: '결제 날짜',
            );
            if (picked != null) {
              setState(() {
                _paidDate = picked;
                _refreshRate();
              });
            }
          },
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
          icon: const Icon(Icons.event_outlined, size: 20),
          label: Text(Fmt.longDate(_paidDate)),
        ),
        const SizedBox(height: 14),
        if (!trip.isKrwTrip) ...[
          const FieldLabel('통화', required: true),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text('${trip.currencyCode} (현지 통화)'),
              ),
              const ButtonSegment(value: true, label: Text('원화')),
            ],
            selected: {_krw},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() {
              _krw = value.first;
              _refreshRate();
            }),
          ),
          const SizedBox(height: 14),
        ],
        FieldLabel(
          '금액 (${_currency == 'KRW' ? '원' : _currency})',
          required: true,
        ),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.numberWithOptions(decimal: !_krw),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(_krw ? r'[0-9]' : r'[0-9.]'),
            ),
          ],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: '0',
            prefixText: '${Fmt.currencySymbols[_currency] ?? _currency} ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (!_krw) ...[
          const SizedBox(height: 14),
          const FieldLabel('환율'),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                selected: _foreignMode == RateMode.api,
                showCheckmark: false,
                label: const Text('그날 환율'),
                onSelected: (_) => setState(() {
                  _foreignMode = RateMode.api;
                  _refreshRate();
                }),
              ),
              ChoiceChip(
                selected: _foreignMode == RateMode.prepaid,
                showCheckmark: false,
                label: const Text('결제자 환전 환율'),
                onSelected: (_) =>
                    setState(() => _foreignMode = RateMode.prepaid),
              ),
              ChoiceChip(
                selected: _foreignMode == RateMode.manual,
                showCheckmark: false,
                label: const Text('직접 입력'),
                onSelected: (_) =>
                    setState(() => _foreignMode = RateMode.manual),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_foreignMode == RateMode.manual)
            TextField(
              controller: _manualRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                hintText: '1${trip.currencyCode}당 원화',
                suffixText: '원 / 1${trip.currencyCode}',
              ),
              onChanged: (_) => setState(() {}),
            ),
          _ConversionHint(
            rate: _rate,
            fixedRate: _effectiveRate,
            mode: _foreignMode,
            amount: amount,
            currency: trip.currencyCode,
            payerName: _payer.name,
          ),
        ],
      ],
    );
  }

  // ---- ② 분담

  Widget _stepTwo() {
    final preview = _preview;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        AppCard(
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title.text,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                preview == null ? '-' : Fmt.krw(preview.amountKrw),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (preview != null && preview.amountLocal != null)
                Text(
                  '${Fmt.money(preview.amountLocal!, trip.currencyCode)} × ${Fmt.number(preview.appliedRate ?? 0)}'
                  '${preview.rateDate == null ? '' : ' · ${Fmt.monthDay(preview.rateDate!)} 기준'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              Text(
                '${_payer.name}님 결제',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<SplitMethod>(
          segments: const [
            ButtonSegment(value: SplitMethod.equal, label: Text('균등')),
            ButtonSegment(value: SplitMethod.item, label: Text('항목별')),
            ButtonSegment(value: SplitMethod.custom, label: Text('개별 금액')),
          ],
          selected: {_split},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            setState(() => _split = value.first);
            _schedulePreview();
          },
        ),
        const SizedBox(height: 16),
        switch (_split) {
          SplitMethod.equal => _equalEditor(),
          SplitMethod.item => _itemEditor(),
          SplitMethod.custom => _customEditor(),
        },
        const SizedBox(height: 16),
        if (_previewError != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDEEF3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _previewError!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          )
        else if (preview != null)
          _SharePreview(preview: preview, trip: trip, loading: _previewing),
      ],
    );
  }

  Widget _equalEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            '나눌 사람 ${_equalMembers.length}명',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _equalMembers = _equalMembers.length == trip.members.length
                    ? {trip.myMemberId}
                    : {for (final m in trip.members) m.memberId};
              });
              _schedulePreview();
            },
            child: Text(
              _equalMembers.length == trip.members.length ? '나만' : '모두',
            ),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final member in trip.members)
            FilterChip(
              selected: _equalMembers.contains(member.memberId),
              label: Text(member.name),
              onSelected: (on) {
                setState(() {
                  if (on) {
                    _equalMembers.add(member.memberId);
                  } else if (_equalMembers.length > 1) {
                    _equalMembers.remove(member.memberId);
                  }
                });
                _schedulePreview();
              },
            ),
        ],
      ),
    ],
  );

  Widget _itemEditor() {
    final total = _krw
        ? (_parse(_amount.text) ?? 0)
        : (_parse(_amount.text) ?? 0);
    final sum = _items.fold<double>(
      0,
      (s, i) => s + (_parse(i.amount.text) ?? 0),
    );
    final diff = total - sum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < _items.length; index++) ...[
          AppCard(
            color: AppColors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _items[index].name,
                        decoration: InputDecoration(
                          hintText: '항목 ${index + 1}',
                          isDense: true,
                        ),
                        onChanged: (_) => _schedulePreview(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _items[index].amount,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: !_krw,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(_krw ? r'[0-9]' : r'[0-9.]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          hintText: '금액',
                          isDense: true,
                          prefixText: Fmt.currencySymbols[_currency] ?? '',
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _schedulePreview();
                        },
                      ),
                    ),
                    if (_items.length > 1)
                      IconButton(
                        tooltip: '항목 빼기',
                        onPressed: () {
                          setState(() => _items.removeAt(index).dispose());
                          _schedulePreview();
                        },
                        icon: const Icon(Icons.close, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final member in trip.members)
                      FilterChip(
                        visualDensity: VisualDensity.compact,
                        selected: _items[index].members.contains(
                          member.memberId,
                        ),
                        label: Text(
                          member.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onSelected: (on) {
                          setState(() {
                            final members = _items[index].members;
                            on
                                ? members.add(member.memberId)
                                : members.remove(member.memberId);
                          });
                          _schedulePreview();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextButton.icon(
          onPressed: () {
            setState(() => _items.add(_ItemState(members: {trip.myMemberId})));
          },
          icon: const Icon(Icons.add),
          label: const Text('항목 추가'),
        ),
        Text(
          diff.abs() < 0.005
              ? '항목 합계가 총액과 같아요'
              : diff > 0
              ? '남은 금액 ${Fmt.money(diff, _currency)}을 항목에 넣어 주세요'
              : '항목 합계가 총액보다 ${Fmt.money(-diff, _currency)} 많아요',
          style: TextStyle(
            fontSize: 12,
            color: diff.abs() < 0.005 ? AppColors.success : AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _customEditor() {
    final total = _preview?.amountKrw ?? 0;
    final sum = _custom.values.fold<int>(
      0,
      (s, c) => s + (_parse(c.text)?.round() ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final member in trip.members)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                MemberAvatar(member.name, radius: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    member.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _custom[member.memberId],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '0',
                      isDense: true,
                      prefixText: '₩ ',
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _schedulePreview();
                    },
                  ),
                ),
              ],
            ),
          ),
        Text(
          sum == total
              ? '개인별 합계가 총액과 같아요'
              : '개인별 합계 ${Fmt.krw(sum)} / 총액 ${Fmt.krw(total)} (${Fmt.signedKrw(total - sum)} 남음)',
          style: TextStyle(
            fontSize: 12,
            color: sum == total ? AppColors.success : AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ConversionHint extends StatelessWidget {
  const _ConversionHint({
    required this.rate,
    required this.fixedRate,
    required this.mode,
    required this.amount,
    required this.currency,
    required this.payerName,
  });

  final Future<ExchangeRate?>? rate;
  final double? fixedRate;
  final RateMode mode;
  final double? amount;
  final String currency;
  final String payerName;

  @override
  Widget build(BuildContext context) {
    Widget line(String text, {Color color = AppColors.muted}) => Padding(
      padding: const EdgeInsets.only(top: 8, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (mode == RateMode.prepaid) {
      if (fixedRate == null) {
        return line(
          '$payerName님의 환전 환율이 없어요. 여행 설정에서 넣을 수 있어요.',
          color: AppColors.warning,
        );
      }
      return line(
        '1$currency = ${Fmt.number(fixedRate!)}원'
        '${amount == null ? '' : ' → 약 ${Fmt.krw((amount! * fixedRate!).round())}'}',
      );
    }
    if (mode == RateMode.manual) {
      return fixedRate == null || amount == null
          ? const SizedBox.shrink()
          : line('약 ${Fmt.krw((amount! * fixedRate!).round())}');
    }
    return FutureBuilder<ExchangeRate?>(
      future: rate,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return line('환율을 불러오는 중…');
        }
        if (value == null) {
          return line(
            '이 날짜의 환율을 찾지 못했어요. "직접 입력"을 써 주세요.',
            color: AppColors.warning,
          );
        }
        return line(
          '${value.unit}$currency = ${Fmt.number(value.unitRateToKrw)}원 · ${Fmt.monthDay(value.rateDate)} 기준'
          '${amount == null ? '' : ' → 약 ${Fmt.krw((amount! * value.rateToKrw).round())}'}',
        );
      },
    );
  }
}

class _SharePreview extends StatelessWidget {
  const _SharePreview({
    required this.preview,
    required this.trip,
    required this.loading,
  });

  final ExpenseDetail preview;
  final TripDetail trip;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final remainder = preview.items
        .where((i) => i.remainderKrw > 0 && i.remainderMember != null)
        .toList();
    return AnimatedOpacity(
      opacity: loading ? .5 : 1,
      duration: const Duration(milliseconds: 150),
      child: AppCard(
        color: AppColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('개인별 부담', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final share in preview.memberShares)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    MemberAvatar(share.name, radius: 13),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        share.isPayer ? '${share.name} · 결제' : share.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Fmt.krw(share.shareKrw),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (share.shareLocal != null)
                          Text(
                            '≈ ${Fmt.money(share.shareLocal!, trip.currencyCode)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (remainder.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '원 단위 끝전 ${Fmt.krw(remainder.fold(0, (s, i) => s + i.remainderKrw))}은 '
                '${remainder.map((i) => i.remainderMember!.name).toSet().join(', ')}님이 부담해요',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// BP-EX-004 등록 완료
class _ExpenseDoneScreen extends StatelessWidget {
  const _ExpenseDoneScreen({required this.trip, required this.expense});

  final TripDetail trip;
  final ExpenseDetail expense;

  @override
  Widget build(BuildContext context) {
    final split = switch (expense.splitMethod) {
      SplitMethod.equal => '${expense.memberShares.length}명 균등',
      SplitMethod.item => '항목 ${expense.items.length}개',
      SplitMethod.custom => '개별 금액',
    };
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            const Icon(Icons.check_circle, size: 56, color: AppColors.success),
            const SizedBox(height: 14),
            const Text(
              '지출을 등록했어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            AppCard(
              color: AppColors.background,
              child: Column(
                children: [
                  Text(
                    expense.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Fmt.krw(expense.amountKrw),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${expense.amountLocal == null ? '' : '${Fmt.money(expense.amountLocal!, trip.currencyCode)} · '}'
                    '${expense.payer.name}님 결제 · $split',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SharePreview(preview: expense, trip: trip, loading: false),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ),
    );
  }
}
