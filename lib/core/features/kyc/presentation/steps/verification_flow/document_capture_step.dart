import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:kyc_verification_app_demo/core/camera/frame_processor.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/ml/quality_model.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/utils/image_utils.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';

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

class _DocumentCaptureStepState extends ConsumerState<DocumentCaptureStep> {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  late final ObjectDetector _objectDetector;
  Timer? _autoCaptureTimer;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: false,
        multipleObjects: false,
      ),
    );
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
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _controller = controller;
    });

    await _startImageStream();
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _controller?.dispose();
    _objectDetector.close();
    super.dispose();
  }

  Future<void> _startImageStream() async {
    if (_controller == null || _isStreaming) return;
    await _controller!.startImageStream((cameraImage) async {
      if (!mounted) return;
      final frame = FrameProcessor.convert(cameraImage);
      if (frame == null) return;

      final quality = await QualityModel.predictFromImage(frame);
      if (!mounted) return;

      ref.read(documentCaptureUiProvider.notifier).updateQuality(
            message: quality.message,
            confidence: quality.confidence,
            isGood: quality.isGood,
          );

      _handleAutoCapture(quality.isGood);
    });
    _isStreaming = true;
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
        notifier.setStatus('No document detected. Try again.');
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

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SelfieCaptureStep(
            captureBundle: KycCaptureBundle(documentPath: normalized.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      notifier.setStatus('Capture failed. Please try again.');
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
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Confidence: ${(uiState.qualityConfidence * 100).toStringAsFixed(0)}%',
              style: context.textTheme.bodySmall,
            ),
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
}
