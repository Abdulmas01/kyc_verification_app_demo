import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/utils/toast_utils.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/kyc_capture_bundle.dart';
import 'processing_step.dart';

class SelfieCaptureStep extends StatefulWidget {
  const SelfieCaptureStep({super.key, required this.captureBundle});

  static const String path = '/kyc/selfie';

  final KycCaptureBundle captureBundle;

  @override
  State<SelfieCaptureStep> createState() => _SelfieCaptureStepState();
}

class _SelfieCaptureStepState extends State<SelfieCaptureStep> {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  bool _isDetecting = false;
  String _statusMessage = 'Align your face inside the frame.';
  String? _errorMessage;

  late final FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: true,
      ),
    );
    _initializeFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _controller = controller;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _captureAndDetect() async {
    if (_controller == null || _isDetecting) return;

    setState(() {
      _isDetecting = true;
      _statusMessage = 'Checking for a face...';
      _errorMessage = null;
    });

    try {
      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;
      if (faces.isEmpty) {
        setState(() {
          _statusMessage = 'No face detected. Try again.';
          _isDetecting = false;
          _errorMessage = 'No face detected. Try again.';
        });
        HapticFeedback.lightImpact();
        ToastUtil.showErrorToast('No face detected. Try again.');
        return;
      }

      HapticFeedback.mediumImpact();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProcessingStep(
            captureBundle: widget.captureBundle.copyWith(
              selfiePath: file.path,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Capture failed. Please try again.';
        _errorMessage = 'Selfie capture failed. Try again.';
      });
      HapticFeedback.lightImpact();
      ToastUtil.showErrorToast('Selfie capture failed. Try again.');
    } finally {
      if (!mounted) return;
      setState(() => _isDetecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selfie & Liveness'),
      ),
      body: Padding(
        padding: AppSpacing.pad16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Follow the prompts',
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'We’ll ask you to blink and turn your head to confirm liveness.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(_statusMessage, style: context.textTheme.bodySmall),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.s8),
              _buildErrorBanner(context, _errorMessage!),
            ],
            const SizedBox(height: AppSpacing.s16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: FutureBuilder<void>(
                    future: _initializeFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (_controller == null ||
                          !_controller!.value.isInitialized) {
                        return Center(
                          child: Text(
                            'Camera unavailable',
                            style: context.textTheme.bodySmall,
                          ),
                        );
                      }

                      return CameraPreview(_controller!);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: ButtonWidget(
                text: _isDetecting ? 'Checking...' : 'Continue',
                enabled: !_isDetecting,
                onTap: _captureAndDetect,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: context.textTheme.bodySmall?.copyWith(
          color: colors.onErrorContainer,
        ),
      ),
    );
  }
}
