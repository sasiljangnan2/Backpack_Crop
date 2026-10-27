import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_services.dart';
import '../config/app_config.dart';
import '../config/server_address.dart';
import '../theme/app_colors.dart';
import 'common.dart';

/// 시험용 빌드에서 서버 주소를 바꾸는 시트. 바꿨으면 true
Future<bool> showServerAddressSheet(BuildContext context) async {
  final changed = await showAppSheet<bool>(
    context,
    title: '서버 주소',
    child: const _ServerAddressForm(),
  );
  return changed ?? false;
}

/// 시작 화면 아래의 작은 버튼. 지금 붙는 서버를 보여 주고, 누르면 바꾼다
class ServerAddressButton extends StatefulWidget {
  const ServerAddressButton({super.key});

  @override
  State<ServerAddressButton> createState() => _ServerAddressButtonState();
}

class _ServerAddressButtonState extends State<ServerAddressButton> {
  @override
  Widget build(BuildContext context) {
    final host = Uri.parse(services.api.baseUrl).authority;
    return TextButton.icon(
      onPressed: () async {
        if (await showServerAddressSheet(context) && mounted) {
          setState(() {});
        }
      },
      style: TextButton.styleFrom(foregroundColor: AppColors.muted),
      icon: const Icon(Icons.dns_outlined, size: 16),
      label: Text('서버 $host', style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ServerAddressForm extends StatefulWidget {
  const _ServerAddressForm();

  @override
  State<_ServerAddressForm> createState() => _ServerAddressFormState();
}

class _ServerAddressFormState extends State<_ServerAddressForm> {
  late final _controller = TextEditingController(text: services.api.baseUrl);
  String? _error;
  bool _checking = false;

  /// 연결 확인에 실패한 주소. 한 번 더 누르면 확인 없이 저장한다
  String? _unreachable;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = ServerAddress.normalize(_controller.text);
    if (url == null) {
      setState(() => _error = '주소를 확인해 주세요. 예: 172.20.10.3:8080');
      return;
    }
    if (url != _unreachable) {
      setState(() {
        _checking = true;
        _error = null;
      });
      final ok = await _reachable(url);
      if (!mounted) {
        return;
      }
      setState(() => _checking = false);
      if (!ok) {
        setState(() {
          _unreachable = url;
          _error =
              '이 주소의 서버에 닿지 않아요. 서버가 켜져 있는지, '
              '휴대폰과 PC가 같은 Wi-Fi(핫스팟)에 있는지 확인해 주세요.';
        });
        return;
      }
    }
    await services.changeServer(url);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  /// 응답 코드는 보지 않는다. 로그인 전이라 401이 와도 서버가 켜져 있다는 뜻이다
  static Future<bool> _reachable(String url) async {
    try {
      await http
          .get(Uri.parse('$url/api/users/me'))
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized = ServerAddress.normalize(_controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PC에서 켠 서버에 붙을 때 PC의 IP 주소를 넣어요. '
          'PC에서 ipconfig를 실행해 Wi-Fi의 IPv4 주소를 보면 돼요. '
          'Wi-Fi를 바꾸면 주소도 바뀌어요.',
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: '172.20.10.3:8080',
            errorText: _error,
            errorMaxLines: 3,
          ),
          onChanged: (_) => setState(() {
            _error = null;
            _unreachable = null;
          }),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 8),
        Text(
          '시험용 앱에만 있는 설정이에요 · 처음 주소 ${AppConfig.apiBaseUrl}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (normalized != AppConfig.apiBaseUrl)
              TextButton(
                onPressed: _checking
                    ? null
                    : () => setState(() {
                        _controller.text = AppConfig.apiBaseUrl;
                        _error = null;
                        _unreachable = null;
                      }),
                child: const Text('처음 주소로'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _checking ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
              child: _checking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      normalized != null && normalized == _unreachable
                          ? '그래도 저장'
                          : '연결 확인 후 저장',
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
