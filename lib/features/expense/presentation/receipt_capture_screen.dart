import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../trip/data/trip_models.dart';
import '../data/expense_models.dart';
import '../data/receipt_parser.dart';
import 'expense_form_screen.dart';

/// BP-EX-002 지출 등록 1/3 · 영수증 촬영. 카메라 화면 위에 촬영 가이드(네 모서리 틀)를 겹쳐 보여 준다.
/// 글자는 기기 안의 ML Kit이 읽는다 (무료, 인터넷 · 키 필요 없음). 사진은 서버로 보내지 않는다.
/// 등록하면 등록한 지출을 돌려준다
class ReceiptCaptureScreen extends StatefulWidget {
  const ReceiptCaptureScreen({super.key, required this.trip});

  final TripDetail trip;

  @override
  State<ReceiptCaptureScreen> createState() => _ReceiptCaptureScreenState();
}

class _ReceiptCaptureScreenState extends State<ReceiptCaptureScreen>
    with WidgetsBindingObserver {
  final _picker = ImagePicker();
  CameraController? _camera;

  /// 카메라를 쓸 수 없을 때의 안내 (권한 거부 · 카메라 없음). null이면 카메라를 쓰는 중
  String? _cameraProblem;
  bool _flash = false;
  bool _reading = false;
  bool _failed = false;
  // 지출 입력 화면을 보는 동안은 카메라를 끈다
  bool _away = false;
  // 권한 창이 닫히며 다시 켜기가 겹치지 않게 한다
  bool _starting = false;

  TripDetail get trip => widget.trip;

  // 여행 통화로 어떤 글자를 읽을지 고른다 (일본어 · 한국어 · 중국어 모델은 영어도 읽는다)
  TextRecognitionScript get _script => switch (trip.currencyCode) {
    'JPY' => TextRecognitionScript.japanese,
    'KRW' => TextRecognitionScript.korean,
    'CNY' || 'TWD' || 'HKD' => TextRecognitionScript.chinese,
    _ => TextRecognitionScript.latin,
  };

  bool get _decimals =>
      !const {'JPY', 'KRW', 'VND', 'IDR', 'TWD'}.contains(trip.currencyCode);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  // 앱이 뒤로 가면 카메라를 놓아 다른 앱이 쓸 수 있게 하고, 돌아오면 다시 켠다
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && !_away && !_reading) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_camera != null || _starting) {
      return;
    }
    _starting = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraProblem = '이 기기에서 카메라를 찾지 못했어요.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);
      if (!mounted || _camera != null) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraProblem = null;
      });
    } on CameraException catch (e) {
      if (mounted) {
        setState(
          () => _cameraProblem = e.code.contains('Access')
              ? '카메라 권한이 없어요. 설정에서 카메라를 허용하거나, 앨범 · 직접 입력을 써 주세요.'
              : '카메라를 켜지 못했어요. 앨범에서 고르거나 직접 입력해 주세요.',
        );
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _stopCamera() async {
    final camera = _camera;
    if (camera == null) {
      return;
    }
    setState(() => _camera = null);
    await camera.dispose();
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null) {
      return;
    }
    final next = !_flash;
    try {
      await camera.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _flash = next);
    } on CameraException {
      // 플래시가 없는 기기
    }
  }

  Future<void> _shoot() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _reading) {
      return;
    }
    if (camera.value.isTakingPicture) {
      return;
    }
    setState(() => _reading = true);
    try {
      final photo = await camera.takePicture();
      await _read(photo.path);
    } on CameraException {
      if (mounted) {
        setState(() {
          _reading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _pickFromAlbum() async {
    final XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 90,
      );
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('앨범을 열 수 없어요. 직접 입력해 주세요.')),
        );
      }
      return;
    }
    if (image == null || !mounted) {
      return;
    }
    setState(() => _reading = true);
    await _read(image.path);
  }

  Future<void> _read(String path) async {
    setState(() => _failed = false);
    final recognizer = TextRecognizer(script: _script);
    try {
      final text = await recognizer.processImage(InputImage.fromFilePath(path));
      final scan = ReceiptParser.parse(rowsOf(text), decimals: _decimals);
      if (!mounted) {
        return;
      }
      if ((scan.total ?? 0) <= 0) {
        setState(() => _failed = true);
        return;
      }
      await _openForm(scan);
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      await recognizer.close();
      if (mounted) {
        setState(() => _reading = false);
      }
    }
  }

  Future<void> _openForm(ReceiptScan? scan) async {
    _away = true;
    await _stopCamera();
    if (!mounted) {
      return;
    }
    final saved = await Navigator.of(context).push<ExpenseDetail>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(trip: trip, receipt: scan),
      ),
    );
    _away = false;
    if (!mounted) {
      return;
    }
    if (saved != null) {
      Navigator.pop(context, saved);
      return;
    }
    // 지출 입력에서 돌아오면 다시 찍을 수 있게 카메라를 켠다
    _flash = false;
    _startCamera();
  }

  void _retry() {
    setState(() => _failed = false);
    _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: !_failed,
        appBar: AppBar(
          backgroundColor: _failed
              ? const Color(0xFF15181C)
              : Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          centerTitle: true,
          title: const Text('영수증 촬영', style: TextStyle(color: Colors.white)),
          actions: [
            if (!_failed && _camera != null)
              IconButton(
                tooltip: _flash ? '플래시 끄기' : '플래시 켜기',
                onPressed: _toggleFlash,
                icon: Icon(_flash ? Icons.flash_on : Icons.flash_off),
              ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(30),
            child: _Steps(),
          ),
        ),
        body: _failed ? _failure() : _viewfinder(),
        bottomNavigationBar: _failed
            ? null
            : ColoredBox(
                color: Colors.black,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 14, 32, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SideButton(
                          icon: Icons.photo_library_outlined,
                          label: '앨범',
                          onTap: _reading ? null : _pickFromAlbum,
                        ),
                        Semantics(
                          button: true,
                          label: '촬영',
                          child: GestureDetector(
                            onTap: _reading || _camera == null ? null : _shoot,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _camera == null
                                      ? Colors.white38
                                      : Colors.white,
                                  width: 4,
                                ),
                              ),
                              padding: const EdgeInsets.all(5),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _camera == null
                                      ? Colors.white38
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _SideButton(
                          icon: Icons.keyboard_alt_outlined,
                          label: '직접 입력',
                          onTap: _reading ? null : () => _openForm(null),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // 카메라 미리보기 + 가이드 틀 · 안내 문구
  Widget _viewfinder() {
    final camera = _camera;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (camera != null && camera.value.isInitialized)
          _CoverPreview(camera: camera)
        else
          const ColoredBox(color: Color(0xFF15181C)),
        // 틀 밖을 살짝 어둡게 해서 영수증을 틀에 맞추기 쉽게 한다
        const CustomPaint(painter: _GuidePainter()),
        Align(
          alignment: const Alignment(0, -.66),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _cameraProblem ?? '영수증 네 모서리를 틀에 맞춰 찍어 주세요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ),
        if (_cameraProblem != null)
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              onPressed: _startCamera,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('카메라 다시 켜기'),
            ),
          )
        else if (camera == null && !_reading)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_reading)
          const ColoredBox(
            color: Color(0xAA000000),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    '영수증을 읽고 있어요',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // BP-EX-002 B 인식 실패: 원인 · 다시 찍는 요령 + 다시 촬영 / 직접 입력
  Widget _failure() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.document_scanner_outlined,
            size: 72,
            color: AppColors.error,
          ),
          const SizedBox(height: 18),
          const Text(
            '영수증을 읽지 못했어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '빛이 반사되었거나 글자가 흐릴 수 있어요.\n밝은 곳에서 영수증을 펴고 다시 찍어 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('다시 촬영'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _openForm(null),
            icon: const Icon(Icons.keyboard_alt_outlined),
            label: const Text('직접 입력하기'),
          ),
          const SizedBox(height: 14),
          const Text(
            '직접 입력해도 항목별 분담 · 정산은 똑같이 할 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// 미리보기를 화면에 꽉 차게 (가로세로 비율을 지키며 남는 부분은 잘라 낸다)
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.camera});

  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    final size = camera.value.previewSize;
    if (size == null) {
      return CameraPreview(camera);
    }
    // previewSize는 센서 기준(가로가 김)이라 세로 화면에서는 뒤집어 쓴다
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(camera),
        ),
      ),
    );
  }
}

/// OCR 줄을 같은 높이끼리 묶어 왼쪽부터 잇는다 (영수증의 "이름 · 수량 · 금액" 열이 따로 읽혀도 한 줄로)
List<ReceiptLine> rowsOf(RecognizedText text) {
  final lines = [
    for (final block in text.blocks)
      for (final line in block.lines) line,
  ]..sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));
  final rows = <List<TextLine>>[];
  for (final line in lines) {
    final last = rows.isEmpty ? null : rows.last;
    if (last != null) {
      final center =
          last.map((l) => l.boundingBox.center.dy).reduce((a, b) => a + b) /
          last.length;
      final height = last
          .map((l) => l.boundingBox.height)
          .reduce((a, b) => a < b ? a : b);
      final tolerance =
          (height < line.boundingBox.height
              ? height
              : line.boundingBox.height) *
          .5;
      if ((line.boundingBox.center.dy - center).abs() <= tolerance) {
        last.add(line);
        continue;
      }
    }
    rows.add([line]);
  }
  return [
    for (final row in rows)
      () {
        row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        final confidences = [for (final l in row) ?l.confidence];
        return ReceiptLine(
          row.map((l) => l.text).join(' '),
          confidences.isEmpty
              ? null
              : confidences.reduce((a, b) => a < b ? a : b),
        );
      }(),
  ];
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          for (final (i, label) in const ['촬영', '확인', '분담'].indexed) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 3,
                    color: i == 0 ? AppColors.primary : Colors.white24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${i + 1} $label',
                    style: TextStyle(
                      color: i == 0 ? Colors.white : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (i < 2) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// 촬영 가이드: 화면 가운데 영수증 틀(네 모서리)과 틀 밖의 옅은 그림자
class _GuidePainter extends CustomPainter {
  const _GuidePainter();

  static Rect frameOf(Size size) {
    final width = size.width * .74;
    final height = size.height * .54;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .56),
      width: width,
      height: height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frameOf(size);
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = const Color(0x66000000));

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 34.0;
    for (final (x, y, dx, dy) in [
      (frame.left, frame.top, 1, 1),
      (frame.right, frame.top, -1, 1),
      (frame.left, frame.bottom, 1, -1),
      (frame.right, frame.bottom, -1, -1),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + len * dx, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x, y + len * dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
