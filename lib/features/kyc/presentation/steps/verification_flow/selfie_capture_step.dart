import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    show
        Face,
        FaceDetector,
        FaceDetectorMode,
        FaceDetectorOptions,
        InputImage,
        InputImageFormat,
        InputImageFormatValue,
        InputImageMetadata,
        InputImageRotation,
        InputImageRotationValue;
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/utils/toast_utils.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/kyc_capture_bundle.dart';
import '../../controllers/selfie_capture_ui_notifier.dart';
import '../../models/selfie_capture_ui_state.dart';
import 'processing_step.dart';

class SelfieCaptureStep extends ConsumerStatefulWidget {
  const SelfieCaptureStep({super.key, required this.captureBundle});

  static const String path = '/kyc/selfie';

  final KycCaptureBundle captureBundle;

  @override
  ConsumerState<SelfieCaptureStep> createState() => _SelfieCaptureStepState();
}

class _SelfieCaptureStepState extends ConsumerState<SelfieCaptureStep> {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  bool _blinkPrimed = false;
  bool _capturingSelfie = false;
  int _frameCounter = 0;

  static const int _frameStride = 4;
  static const double _blinkClosedThreshold = 0.25;
  static const double _blinkOpenThreshold = 0.7;
  static const double _headTurnThreshold = 18;
  static const double _lookStraightThreshold = 8;

  late final FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: true,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
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
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _controller = controller;
    });
    ref.read(selfieCaptureUiProvider.notifier).resetFlow();
    await _startImageStream();
  }

  @override
  void dispose() {
    unawaited(_stopImageStream());
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _startImageStream() async {
    if (_controller == null || _isStreaming) return;
    await _controller!.startImageStream((cameraImage) {
      if (!mounted || _capturingSelfie) return;
      _frameCounter++;
      if (_frameCounter % _frameStride != 0) return;
      if (_isProcessingFrame) return;

      _isProcessingFrame = true;
      unawaited(_processCameraFrame(cameraImage));
    });
    _isStreaming = true;
  }

  Future<void> _stopImageStream() async {
    if (_controller == null || !_isStreaming) return;
    await _controller!.stopImageStream();
    _isStreaming = false;
  }

  Future<void> _processCameraFrame(CameraImage cameraImage) async {
    final selfieCaptureUiNotifier = ref.read(selfieCaptureUiProvider.notifier);
    try {
      final inputImage = _inputImageFromCameraImage(cameraImage);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        _blinkPrimed = false;
        selfieCaptureUiNotifier.setFaceDetected(false);
        selfieCaptureUiNotifier.setChallengeMessage(
          'Center your face in the oval to continue.',
        );
        return;
      }

      if (faces.length > 1) {
        selfieCaptureUiNotifier.setFaceDetected(false);
        selfieCaptureUiNotifier.setError(
          statusMessage: 'Only one face should be visible.',
          errorMessage: 'Multiple faces detected. Please continue alone.',
        );
        return;
      }

      final face = faces.first;
      selfieCaptureUiNotifier.setFaceDetected(true);
      await _handleChallenge(face);
    } catch (_) {
      if (!mounted) return;
      selfieCaptureUiNotifier.setError(
        statusMessage: 'We could not read your face clearly.',
        errorMessage: 'Face analysis failed. Please try again.',
      );
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _handleChallenge(Face face) async {
    final selfieCaptureUiNotifier = ref.read(selfieCaptureUiProvider.notifier);
    final uiState = ref.read(selfieCaptureUiProvider);

    switch (uiState.currentChallenge) {
      case SelfieLivenessChallenge.blink:
        final leftEyeOpen = face.leftEyeOpenProbability;
        final rightEyeOpen = face.rightEyeOpenProbability;
        if (leftEyeOpen == null || rightEyeOpen == null) {
          selfieCaptureUiNotifier.setChallengeMessage(
            'Keep your face well lit, then blink naturally.',
          );
          return;
        }

        if (leftEyeOpen > _blinkOpenThreshold &&
            rightEyeOpen > _blinkOpenThreshold) {
          _blinkPrimed = true;
          selfieCaptureUiNotifier.setChallengeMessage(
            'Blink naturally to continue.',
          );
          return;
        }

        if (_blinkPrimed &&
            leftEyeOpen < _blinkClosedThreshold &&
            rightEyeOpen < _blinkClosedThreshold) {
          _blinkPrimed = false;
          selfieCaptureUiNotifier.markBlinkComplete();
          HapticFeedback.mediumImpact();
        }
        return;
      case SelfieLivenessChallenge.turnLeft:
        final yAngle = face.headEulerAngleY ?? 0;
        if (yAngle < -_headTurnThreshold) {
          selfieCaptureUiNotifier.markTurnLeftComplete();
          HapticFeedback.mediumImpact();
        } else {
          selfieCaptureUiNotifier.setChallengeMessage(
            'Slowly turn your head to the left.',
          );
        }
        return;
      case SelfieLivenessChallenge.turnRight:
        final yAngle = face.headEulerAngleY ?? 0;
        if (yAngle > _headTurnThreshold) {
          selfieCaptureUiNotifier.markTurnRightComplete();
          HapticFeedback.mediumImpact();
        } else {
          selfieCaptureUiNotifier.setChallengeMessage(
            'Now turn your head to the right.',
          );
        }
        return;
      case SelfieLivenessChallenge.lookStraight:
        final yAngle = face.headEulerAngleY ?? 0;
        if (yAngle.abs() <= _lookStraightThreshold) {
          selfieCaptureUiNotifier.startAutoCapture();
          HapticFeedback.selectionClick();
          await _captureSelfie();
        } else {
          selfieCaptureUiNotifier.setChallengeMessage(
            'Look straight at the camera and hold still.',
          );
        }
        return;
      case SelfieLivenessChallenge.complete:
        return;
    }
  }

  Future<void> _captureSelfie() async {
    final selfieCaptureUiNotifier = ref.read(selfieCaptureUiProvider.notifier);
    if (_controller == null || _capturingSelfie) return;
    _capturingSelfie = true;
    try {
      await _stopImageStream();
      selfieCaptureUiNotifier.startCapture();
      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;
      if (faces.isEmpty) {
        selfieCaptureUiNotifier.setError(
          statusMessage: 'No face detected. Try again.',
          errorMessage: 'No face detected. Try again.',
        );
        HapticFeedback.lightImpact();
        ToastUtil.showErrorToast('No face detected. Try again.');
        await _startImageStream();
        return;
      }

      selfieCaptureUiNotifier.completeFlow();
      HapticFeedback.heavyImpact();
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
      selfieCaptureUiNotifier.setError(
        statusMessage: 'Capture failed. Please try again.',
        errorMessage: 'Selfie capture failed. Try again.',
      );
      HapticFeedback.lightImpact();
      ToastUtil.showErrorToast('Selfie capture failed. Try again.');
      await _startImageStream();
    } finally {
      _capturingSelfie = false;
      if (mounted && ref.read(selfieCaptureUiProvider).hasError) {
        selfieCaptureUiNotifier.resetFlow();
        await _startImageStream();
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;

    final camera = controller.description;
    final rotation = _inputImageRotationFromCamera(controller, camera);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (Platform.isAndroid &&
        format != InputImageFormat.nv21 &&
        format != InputImageFormat.yuv_420_888) {
      return null;
    }

    final writeBuffer = WriteBuffer();
    for (final plane in image.planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    final bytes = writeBuffer.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _inputImageRotationFromCamera(
    CameraController controller,
    CameraDescription camera,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }

    const orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    final rotationCompensation =
        orientations[controller.value.deviceOrientation];
    if (rotationCompensation == null) return null;

    final adjustedRotation = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + rotationCompensation) % 360
        : (camera.sensorOrientation - rotationCompensation + 360) % 360;

    return InputImageRotationValue.fromRawValue(adjustedRotation);
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(selfieCaptureUiProvider);

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
            _ChallengeProgressCard(uiState: uiState),
            const SizedBox(height: AppSpacing.s12),
            Text(uiState.statusMessage, style: context.textTheme.bodySmall),
            if (uiState.hasError) ...[
              const SizedBox(height: AppSpacing.s8),
              _ErrorBanner(message: uiState.errorMessage ?? ''),
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

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_controller!),
                          const _FaceOvalOverlay(),
                          Positioned(
                            top: AppSpacing.s16,
                            left: AppSpacing.s16,
                            right: AppSpacing.s16,
                            child: _DetectionBadge(
                              isFaceDetected: uiState.isFaceDetected,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: ButtonWidget(
                text: uiState.isAutoCapturing
                    ? 'Capturing...'
                    : 'Restart liveness check',
                enabled: !uiState.isAutoCapturing,
                onTap: () {
                  ref.read(selfieCaptureUiProvider.notifier).resetFlow();
                  _blinkPrimed = false;
                  HapticFeedback.selectionClick();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
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

class _ChallengeProgressCard extends StatelessWidget {
  const _ChallengeProgressCard({required this.uiState});

  final SelfieCaptureUiState uiState;

  @override
  Widget build(BuildContext context) {
    final labels = [
      ('Blink', uiState.completedChallenges >= 1),
      ('Turn left', uiState.completedChallenges >= 2),
      ('Turn right', uiState.completedChallenges >= 3),
    ];

    return Container(
      width: double.infinity,
      padding: AppSpacing.padH16V12,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Liveness progress',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s8),
          LinearProgressIndicator(value: uiState.progress.clamp(0, 1)),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: labels
                .map(
                  (item) => _ChallengeChip(
                    label: item.$1,
                    completed: item.$2,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ChallengeChip extends StatelessWidget {
  const _ChallengeChip({
    required this.label,
    required this.completed,
  });

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: completed ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: completed ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: Text(
        completed ? '$label done' : label,
        style: context.textTheme.bodySmall?.copyWith(
          color: completed ? colors.onPrimaryContainer : colors.onSurface,
        ),
      ),
    );
  }
}

class _DetectionBadge extends StatelessWidget {
  const _DetectionBadge({required this.isFaceDetected});

  final bool isFaceDetected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = isFaceDetected
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final foreground =
        isFaceDetected ? colors.onPrimaryContainer : colors.onSurfaceVariant;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isFaceDetected ? 'Face detected' : 'Waiting for face',
          style: context.textTheme.bodySmall?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _FaceOvalOverlay extends StatelessWidget {
  const _FaceOvalOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 220,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
