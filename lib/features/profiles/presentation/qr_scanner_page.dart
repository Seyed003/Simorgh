import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/context_ext.dart';
import '../../../core/utils/qr_decoder.dart';

/// Live camera QR scanner built on the official camera plugin and the pure
/// Dart zxing2 decoder (no proprietary ML Kit dependency). Pops with the
/// decoded text.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  CameraController? _camera;
  String? _error;
  bool _decoding = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', null);
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.code.contains('AccessDenied') || e.code.contains('Permission')
            ? context.l10n.cameraPermissionDenied
            : context.l10n.cameraUnavailable;
      });
    }
  }

  void _onFrame(CameraImage image) {
    if (_decoding || _done) return;
    _decoding = true;
    final plane = image.planes.first;
    final luma = Uint8List.fromList(plane.bytes);
    final width = image.width;
    final height = image.height;
    final stride = plane.bytesPerRow;
    Isolate.run(
      () => QrDecoder.decodeLuminance(luma, width, height, rowStride: stride),
    ).then(
      (text) {
        _decoding = false;
        if (text == null || _done || !mounted) return;
        _done = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(text);
      },
      onError: (Object _) {
        _decoding = false;
      },
    );
  }

  @override
  void dispose() {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      unawaited(() async {
        if (camera.value.isStreamingImages) await camera.stopImageStream();
        await camera.dispose();
      }());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.l10n.scanQrCode),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            )
          : camera == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                Center(child: CameraPreview(camera)),
                const _ScanOverlay(),
                PositionedDirectional(
                  start: 24,
                  end: 24,
                  bottom: 48,
                  child: Text(
                    context.l10n.qrScanHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
