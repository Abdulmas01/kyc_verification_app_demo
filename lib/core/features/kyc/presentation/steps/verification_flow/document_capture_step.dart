import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/ml/quality_model.dart';
import 'package:kyc_verification_app_demo/core/ml/quality_isolate.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/utils/logger.dart';
import 'package:kyc_verification_app_demo/core/utils/toast_utils.dart';
import 'package:kyc_verification_app_demo/core/utils/image_utils.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';
import 'package:flutter/services.dart';
import 'package:kyc_verification_app_demo/core/utils/app_assets.dart';

import '../../../domain/models/kyc_capture_bundle.dart';
import '../../controllers/document_capture_ui_notifier.dart';
import '../../widgets/document_overlay_widget.dart';
import 'selfie_capture_step.dart';

class DocumentCaptureStep extends ConsumerStatefulWidget {
  const DocumentCaptureStep({super.key});

  static const String path = '/kyc/document';

  @override
  ConsumerState<DocumentCaptureStep> createState() =>
      _DocumentCaptureStepState();
}

class _DocumentCaptureStepState extends ConsumerState<DocumentCaptureStep>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  late final ObjectDetector _objectDetector;
  Timer? _autoCaptureTimer;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  int _frameCounter = 0;
  QualityIsolate? _qualityIsolate;

  static const int _minStride = 3;
  static const int _maxStride = 8;
  int _frameStride = 5;
  int _strideAdjustCounter = 0;
  double _avgInferenceMs = 0;
  int _inferenceSamples = 0;
  static const int _logEvery = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: false,
        multipleObjects: false,
      ),
    );
    _qualityIsolate = QualityIsolate(assetPath: AppAssets.docQualityModel);

    _initializeFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _controller = controller;
    });

    await _qualityIsolate?.start();
    if (!mounted) return;
    await _startImageStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCaptureTimer?.cancel();
    _controller?.dispose();
    _objectDetector.close();
    _qualityIsolate?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _resumeCamera();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _pauseCamera();
        break;
    }
  }

  Future<void> _pauseCamera() async {
    _autoCaptureTimer?.cancel();
    _isProcessingFrame = false;
    if (_controller?.value.isStreamingImages ?? false) {
      await _controller?.stopImageStream();
      _isStreaming = false;
    }
  }

  Future<void> _resumeCamera() async {
    if (_controller == null || !(_controller?.value.isInitialized ?? false)) {
      _initializeFuture = _initCamera();
      return;
    }
    if (!_isStreaming) {
      await _startImageStream();
    }
  }

  Future<void> _startImageStream() async {
    if (_controller == null || _isStreaming) return;
    await _controller!.startImageStream((cameraImage) {
      if (!mounted) return;
      _frameCounter++;
      if (_frameCounter % _frameStride != 0) return;
      if (_isProcessingFrame) return;

      _isProcessingFrame = true;
      final payload = _qualityIsolate?.buildPayload(cameraImage);
      if (payload == null) {
        _isProcessingFrame = false;
        return;
      }
      unawaited(_processPayload(payload));
    });
    _isStreaming = true;
  }

  Future<void> _processPayload(Map<String, Object?> payload) async {
    final stopwatch = Stopwatch()..start();
    try {
      final probs = await _qualityIsolate?.predictPayload(payload);
      if (!mounted) return;
      if (probs == null) return;
      final quality = QualityModel.fromProbabilities(probs);

      ref.read(documentCaptureUiProvider.notifier).updateQuality(
            message: quality.message,
            confidence: quality.confidence,
            isGood: quality.isGood,
          );

      _handleAutoCapture(quality.isGood);
      _recordInference(
        stopwatch.elapsedMicroseconds / 1000,
        quality: quality,
      );
    } on TimeoutException {
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _recordInference(double ms, {QualityResult? quality}) {
    _inferenceSamples++;
    _avgInferenceMs =
        ((_avgInferenceMs * (_inferenceSamples - 1)) + ms) / _inferenceSamples;

    _strideAdjustCounter++;
    if (_strideAdjustCounter >= 10) {
      if (_avgInferenceMs > 80 && _frameStride < _maxStride) {
        _frameStride++;
      } else if (_avgInferenceMs < 40 && _frameStride > _minStride) {
        _frameStride--;
      }
      _strideAdjustCounter = 0;
    }

    if (_inferenceSamples % _logEvery == 0) {
      logPrint(
        'DocQuality avg inference: ${_avgInferenceMs.toStringAsFixed(1)}ms '
        '(stride=$_frameStride)',
      );
      if (quality != null) {
        logPrint(
          'DocQuality last: ${quality.quality} '
          'conf=${(quality.confidence * 100).toStringAsFixed(1)}%',
        );
      }
    }
  }

  void _handleAutoCapture(bool isGood) {
    if (isGood) {
      if (_autoCaptureTimer?.isActive ?? false) return;
      ref.read(documentCaptureUiProvider.notifier).setAutoCapturing(true);
      _autoCaptureTimer = Timer(const Duration(milliseconds: 1500), () {
        ref.read(documentCaptureUiProvider.notifier).setAutoCapturing(false);
        _captureAndDetect();
      });
    } else {
      _autoCaptureTimer?.cancel();
      ref.read(documentCaptureUiProvider.notifier).setAutoCapturing(false);
    }
  }

  Future<void> _captureAndDetect() async {
    final notifier = ref.read(documentCaptureUiProvider.notifier);
    final uiState = ref.read(documentCaptureUiProvider);
    if (_controller == null || uiState.isDetecting) return;

    notifier.setDetecting(true);
    notifier.setStatus('Detecting document...');

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
        _isStreaming = false;
      }

      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final objects = await _objectDetector.processImage(inputImage);

      if (!mounted) return;
      final detectedObject = objects.isNotEmpty ? objects.first : null;
      if (detectedObject == null) {
        notifier.setDocumentDetected(false);
        notifier.setError('No document detected. Try again.');
        HapticFeedback.lightImpact();
        await _startImageStream();
        return;
      }

      final normalized = await ImageUtils.normalizeDocumentImage(
        inputPath: file.path,
        boundingBox: detectedObject.boundingBox,
      );

      if (!mounted) return;
      notifier.setDocumentDetected(true);
      notifier.setStatus('Document detected. Looks good!');
      notifier.clearError();
      HapticFeedback.mediumImpact();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SelfieCaptureStep(
            captureBundle: KycCaptureBundle(documentPath: normalized.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      notifier.setError('Capture failed. Please try again.');
      ToastUtil.showErrorToast('Document capture failed. Try again.');
    } finally {
      if (!mounted) return;
      notifier.setDetecting(false);
      if (_controller != null && !_isStreaming) {
        await _startImageStream();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(documentCaptureUiProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Capture'),
      ),
      body: Padding(
        padding: AppSpacing.pad16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Place your ID inside the frame',
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'We will guide you to get a clear, glare‑free capture.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(uiState.statusMessage, style: context.textTheme.bodySmall),
            if (uiState.hasError) ...[
              const SizedBox(height: AppSpacing.s8),
              _buildErrorBanner(context, uiState.errorMessage ?? ''),
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
                          const DocumentOverlayWidget(),
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
                text: uiState.isDetecting ? 'Detecting...' : 'Capture Document',
                enabled: !uiState.isDetecting && uiState.isQualityGood,
                onTap: _captureAndDetect,
              ),
            ),
            if (uiState.isAutoCapturing) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Auto‑capturing...',
                style: context.textTheme.bodySmall,
              ),
            ],
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
