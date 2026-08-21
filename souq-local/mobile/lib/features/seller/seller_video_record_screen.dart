import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/margem_app_bar.dart';
import '../../l10n/app_localizations.dart';
import 'seller_video_constants.dart';

class SellerVideoRecordScreen extends StatefulWidget {
  const SellerVideoRecordScreen({super.key});

  @override
  State<SellerVideoRecordScreen> createState() => _SellerVideoRecordScreenState();
}

class _SellerVideoRecordScreenState extends State<SellerVideoRecordScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No camera available';
          _initializing = false;
        });
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.cameraPermissionDenied;
        _initializing = false;
      });
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _recording) {
      return;
    }
    await controller.startVideoRecording();
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      final next = _elapsed + const Duration(seconds: 1);
      if (next.inSeconds >= maxVideoDurationSeconds) {
        await _stopRecording(autoStopped: true);
        return;
      }
      setState(() => _elapsed = next);
    });
  }

  Future<void> _stopRecording({bool autoStopped = false}) async {
    final controller = _controller;
    if (controller == null || !_recording) return;
    _timer?.cancel();
    setState(() => _recording = false);
    try {
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      context.pop(File(file.path));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.somethingWentWrong);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  String _format(Duration value) {
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: MarGemAppBar(
        backgroundColor: Colors.black,
        semanticLabel: l10n.createVideo,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : controller == null || !controller.value.isInitialized
                  ? const SizedBox.shrink()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller),
                        Align(
                          alignment: Alignment.topCenter,
                          child: SafeArea(
                            child: Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_format(_elapsed)} / 00:59',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: GestureDetector(
                                onTap: _recording ? () => _stopRecording() : _startRecording,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                    color: _recording
                                        ? context.colors.error
                                        : Colors.white24,
                                  ),
                                  child: Icon(
                                    _recording ? Icons.stop_rounded : Icons.fiber_manual_record,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
