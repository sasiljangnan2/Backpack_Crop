import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_services.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';

/// BP-TR-003 초대 코드로 참여. 성공하면 여행 ID를 돌려준다.
class JoinTripScreen extends StatefulWidget {
  const JoinTripScreen({super.key});

  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  static const _length = 8;
  // 서버가 쓰는 글자: 대문자 + 숫자, 0 O 1 I 제외
  static final _allowed = RegExp('[A-HJ-NP-Z2-9]');

  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;

  String get _code => _controller.text;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = (data?.text ?? '')
        .toUpperCase()
        .split('')
        .where(_allowed.hasMatch)
        .join();
    if (text.isNotEmpty) {
      _controller.text = text.substring(0, text.length.clamp(0, _length));
      setState(() => _error = null);
    }
  }

  Future<void> _submit() async {
    if (_code.length != _length || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final trip = await services.trips.join(_code);
      if (mounted) {
        Navigator.pop(context, trip.id);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(
        () => _error = switch (e.code) {
          'INVITE_CODE_NOT_FOUND' => '초대 코드를 다시 확인해 주세요.',
          'TRIP_FULL' => '여행 인원이 가득 찼어요.',
          _ => e.displayMessage,
        },
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('초대 코드로 참여'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const Text(
            '친구에게 받은 8자리 코드를 입력해 주세요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _focus.requestFocus(),
            child: Stack(
              children: [
                // 실제 입력은 보이지 않는 텍스트 칸이 받고, 칸 8개는 그 값을 보여 준다
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    height: 56,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: [
                        _UpperCaseFormatter(),
                        FilteringTextInputFormatter.allow(_allowed),
                        LengthLimitingTextInputFormatter(_length),
                      ],
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < _length; i++) ...[
                      if (i == 4) const SizedBox(width: 10),
                      Expanded(
                        child: _CodeBox(
                          char: i < _code.length ? _code[i] : '',
                          active: _focus.hasFocus && i == _code.length,
                          error: _error != null,
                        ),
                      ),
                      if (i != _length - 1 && i != 3) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('붙여넣기'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: _code.length == _length && !_busy ? _submit : null,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('참여하기'),
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.char,
    required this.active,
    required this.error,
  });

  final String char;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? AppColors.error
        : active
        ? AppColors.primary
        : AppColors.border;
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: active || error ? 1.6 : 1),
      ),
      child: Text(
        char,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
