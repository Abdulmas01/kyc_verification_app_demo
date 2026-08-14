import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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
import 'package:permission_handler/permission_handler.dart';

import '../../../domain/models/kyc_capture_bundle.dart';
import '../../../data/services/document_quality_debug_exporter.dart';
import '../../controllers/document_capture_ui_notifier.dart';
import '../../controllers/thesis_debug_report_notifier.dart';
import '../../models/kyc_capture_config.dart';
import '../../widgets/document_overlay_widget.dart';
import 'selfie_capture_step.dart';

class DocumentCaptureStep extends ConsumerStatefulWidget {
  const DocumentCaptureStep({
    super.key,
    this.captureProfile,
    this.captureConfig = const DocumentCaptureConfig.balanced(),
  });

  static const String path = '/kyc/document';

  final KycCaptureProfile? captureProfile;
  final DocumentCaptureConfig captureConfig;

  DocumentCaptureConfig get effectiveCaptureConfig =>
      captureProfile?.documentCapture ?? captureConfig;

  @override
  ConsumerState<DocumentCaptureStep> createState() =>
      _DocumentCaptureStepState();
}

class _DocumentCaptureStepState extends ConsumerState<DocumentCaptureStep>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  Future<void>? _cameraSetupFuture;
  late final ObjectDetector _objectDetector;
  Timer? _autoCaptureTimer;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  int _frameCounter = 0;
  QualityIsolate? _qualityIsolate;
  DocumentQuality? _pendingGuidanceQuality;
  int _pendingGuidanceCount = 0;
  DocumentQuality? _activeGuidanceQuality;
  final Stopwatch _sessionStopwatch = Stopwatch();
  Duration _lastGuidanceTransitionAt = Duration.zero;
  String? _lastGuidanceMessage;
  DocumentQuality? _lastLoggedRawQuality;
  DocumentQuality? _lastLoggedGuidanceQuality;
  bool _lastGuidanceHoldLogged = false;
  bool _pendingDebugSampleExport = false;
  bool _isNavigatingToSelfie = false;
  Future<void>? _controllerDisposeFuture;

  static const double _strongNegativeGuidanceThreshold = 0.50;
  static const double _strongNegativeImmediateThreshold = 0.65;

  late int _frameStride;
  int _strideAdjustCounter = 0;
  double _avgInferenceMs = 0;
  int _inferenceSamples = 0;

  @override
  void initState() {
    super.initState();
    _sessionStopwatch.start();
    _frameStride = widget.effectiveCaptureConfig.initialFrameStride;
    WidgetsBinding.instance.addObserver(this);
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: false,
        multipleObjects: false,
      ),
    );
    _qualityIsolate = QualityIsolate(assetPath: AppAssets.docQualityModel);
    _initializeFuture = Future.value();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(thesisDebugReportProvider.notifier).startRun(
            documentConfig:
                _documentConfigToJson(widget.effectiveCaptureConfig),
          );
      setState(() {
        _initializeFuture = _ensureCameraInitialized();
      });
    });
  }

  Future<void> _ensureCameraInitialized() {
    final existing = _cameraSetupFuture;
    if (existing != null) return existing;
    late final Future<void> future;
    future = _initCamera().whenComplete(() {
      if (identical(_cameraSetupFuture, future)) {
        _cameraSetupFuture = null;
      }
    });
    _cameraSetupFuture = future;
    return future;
  }

  Future<void> _disposeController() async {
    final existing = _controllerDisposeFuture;
    if (existing != null) return existing;
    late final Future<void> future;
    future = _disposeControllerInternal().whenComplete(() {
      if (identical(_controllerDisposeFuture, future)) {
        _controllerDisposeFuture = null;
      }
    });
    _controllerDisposeFuture = future;
    return future;
  }

  Future<void> _disposeControllerInternal() async {
    final controller = _controller;
    _controller = null;
    _isStreaming = false;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } on CameraException catch (error) {
      logPrint('Document camera stop stream ignored during dispose: ${error.code}');
    } catch (_) {
      logPrint('Document camera stop stream ignored during dispose.');
    }
    try {
      await controller.dispose();
    } on CameraException catch (error) {
      logPrint('Document camera dispose ignored: ${error.code}');
    } catch (_) {
      logPrint('Document camera dispose ignored.');
    }
  }

  Future<void> _initCamera() async {
    final notifier = ref.read(documentCaptureUiProvider.notifier);
    notifier.resetFlow();

    final permission = await Permission.camera.request();
    if (!mounted) return;

    if (!permission.isGranted) {
      ref.read(thesisDebugReportProvider.notifier).recordDocumentFailure(
            permission.isPermanentlyDenied || permission.isRestricted
                ? 'Camera permission permanently denied.'
                : 'Camera permission denied.',
          );
      notifier.setPermissionDenied(
        permanentlyDenied:
            permission.isPermanentlyDenied || permission.isRestricted,
      );
      return;
    }

    notifier.clearPermissionError();

    try {
      await _disposeController();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        notifier.setCameraError('No camera is available on this device.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        widget.effectiveCaptureConfig.resolutionPreset,
        enableAudio: false,
        imageFormatGroup: widget.effectiveCaptureConfig.imageFormatGroup,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
      });

      await _qualityIsolate?.start();
      if (!mounted) return;
      notifier.setCameraReady(true);
      await _startImageStream();
    } on CameraException catch (e) {
      final userMessage = _cameraErrorMessage(
        e.code,
        e.description,
        lensLabel: 'back',
      );
      ref.read(thesisDebugReportProvider.notifier).recordDocumentFailure(
            e.description ?? userMessage,
          );
      notifier.setCameraError(userMessage);
    } catch (_) {
      ref
          .read(thesisDebugReportProvider.notifier)
          .recordDocumentFailure('Unable to start the back camera.');
      notifier.setCameraError('Unable to start the back camera.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCaptureTimer?.cancel();
    unawaited(_disposeController());
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
    _frameStride = widget.effectiveCaptureConfig.initialFrameStride;
    _isProcessingFrame = false;
    if (_controller?.value.isStreamingImages ?? false) {
      await _controller?.stopImageStream();
      _isStreaming = false;
    }
  }

  Future<void> _resumeCamera() async {
    final uiState = ref.read(documentCaptureUiProvider);
    if (uiState.isPermissionDenied || uiState.isPermanentlyDenied) {
      return;
    }
    if (_controller == null || !(_controller?.value.isInitialized ?? false)) {
      _initializeFuture = _ensureCameraInitialized();
      if (mounted) setState(() {});
      return;
    }
    await _resumePreviewIfNeeded();
    if ((_controller?.value.isStreamingImages ?? false) && !_isStreaming) {
      _isStreaming = true;
    }
    if (!_isStreaming) {
      await _startImageStream();
    }
  }

  Future<void> _startImageStream() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      _isStreaming = true;
      return;
    }
    if (_isStreaming) return;
    await controller.startImageStream((cameraImage) {
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
      if (!_shouldProcessLiveQualityFrames) return;
      final inference = await _qualityIsolate?.predictPayload(
        payload,
        includeDebugArtifacts: _pendingDebugSampleExport,
      );
      if (!mounted) return;
      if (!_shouldProcessLiveQualityFrames) return;
      if (inference == null) return;
      final quality = QualityModel.fromProbabilities(inference.probabilities);
      final guidanceQuality = _resolveGuidanceQuality(quality);
      final guidanceMessage = _messageForQuality(guidanceQuality);
      _logQualityTransition(
        quality: quality,
        guidanceQuality: guidanceQuality,
        guidanceMessage: guidanceMessage,
        inferenceMs: stopwatch.elapsedMicroseconds / 1000,
      );

      final allowsQualityAcceptance = _allowsQualityAcceptance(quality);
      ref.read(documentCaptureUiProvider.notifier).updateQuality(
            message: guidanceMessage,
            confidence: quality.confidence,
            isGood: allowsQualityAcceptance,
          );
      ref.read(thesisDebugReportProvider.notifier).recordDocumentQuality(
            statusMessage: guidanceMessage,
            qualityLabel: quality.quality.name,
            confidence: quality.confidence,
            accepted: allowsQualityAcceptance,
            averageInferenceMs: _avgInferenceMs == 0
                ? stopwatch.elapsedMicroseconds / 1000
                : _avgInferenceMs,
            inferenceSamples: _inferenceSamples,
            frameStride: _frameStride,
          );

      _handleAutoCapture(
        quality: quality,
        allowsQualityAcceptance: allowsQualityAcceptance,
      );
      await _maybeExportDebugSample(
        inference: inference,
        quality: quality,
        guidanceQuality: guidanceQuality,
        guidanceMessage: guidanceMessage,
        inferenceMs: stopwatch.elapsedMicroseconds / 1000,
      );
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

  Future<void> _maybeExportDebugSample({
    required QualityInferenceResult inference,
    required QualityResult quality,
    required DocumentQuality guidanceQuality,
    required String guidanceMessage,
    required double inferenceMs,
  }) async {
    if (!_pendingDebugSampleExport) return;
    _pendingDebugSampleExport = false;
    final debugArtifacts = inference.debugArtifacts;
    if (debugArtifacts == null) return;

    final runId = ref.read(thesisDebugReportProvider).runId;
    final exportResult = await ref
        .read(documentQualityDebugExporterProvider)
        .exportLiveSample(
          runId: runId,
          quality: quality,
          displayedGuidance: guidanceQuality,
          guidanceMessage: guidanceMessage,
          inferenceMs: inferenceMs,
          frameNumber: _frameCounter,
          frameStride: _frameStride,
          documentConfig: _documentConfigToJson(widget.effectiveCaptureConfig),
          debugArtifacts: debugArtifacts,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Quality sample exported to ${exportResult.directoryPath}',
        ),
      ),
    );
  }

  DocumentQuality _resolveGuidanceQuality(QualityResult quality) {
    final nextQuality = quality.guidanceQuality;
    if (_activeGuidanceQuality == null) {
      _activeGuidanceQuality = nextQuality;
      _pendingGuidanceQuality = null;
      _pendingGuidanceCount = 0;
      _lastGuidanceHoldLogged = false;
      return nextQuality;
    }

    if (nextQuality == _activeGuidanceQuality) {
      _pendingGuidanceQuality = null;
      _pendingGuidanceCount = 0;
      _lastGuidanceHoldLogged = false;
      return _activeGuidanceQuality!;
    }

    if (_shouldImmediatelySwitchGuidance(quality, nextQuality)) {
      _activeGuidanceQuality = nextQuality;
      _pendingGuidanceQuality = null;
      _pendingGuidanceCount = 0;
      _lastGuidanceHoldLogged = false;
      return nextQuality;
    }

    if (_pendingGuidanceQuality != nextQuality) {
      _pendingGuidanceQuality = nextQuality;
      _pendingGuidanceCount = 1;
      _logGuidanceHold(
        quality: quality,
        activeQuality: _activeGuidanceQuality!,
        pendingQuality: nextQuality,
      );
      return _activeGuidanceQuality!;
    }

    _pendingGuidanceCount++;
    if (_pendingGuidanceCount <
        widget.effectiveCaptureConfig.guidanceStabilityFrames) {
      _logGuidanceHold(
        quality: quality,
        activeQuality: _activeGuidanceQuality!,
        pendingQuality: nextQuality,
      );
      return _activeGuidanceQuality!;
    }

    _activeGuidanceQuality = nextQuality;
    _pendingGuidanceQuality = null;
    _pendingGuidanceCount = 0;
    _lastGuidanceHoldLogged = false;
    return nextQuality;
  }

  bool _shouldImmediatelySwitchGuidance(
    QualityResult quality,
    DocumentQuality nextQuality,
  ) {
    if (_activeGuidanceQuality == DocumentQuality.good &&
        nextQuality != DocumentQuality.good) {
      return quality.confidence >= _strongNegativeGuidanceThreshold;
    }

    if (_activeGuidanceQuality != null &&
        _activeGuidanceQuality != nextQuality &&
        nextQuality != DocumentQuality.noDocument &&
        quality.confidence >= _strongNegativeImmediateThreshold) {
      return true;
    }

    return false;
  }

  void _logGuidanceHold({
    required QualityResult quality,
    required DocumentQuality activeQuality,
    required DocumentQuality pendingQuality,
  }) {
    if (_lastGuidanceHoldLogged) return;
    _lastGuidanceHoldLogged = true;
    logPrint(
      [
        'DocQuality hold',
        'session=${_formatDuration(_sessionStopwatch.elapsed)}',
        'frame=$_frameCounter',
        'raw=${quality.quality.name}:${(quality.confidence * 100).toStringAsFixed(1)}%',
        'active=${activeQuality.name}',
        'pending=${pendingQuality.name}',
        'pending_count=$_pendingGuidanceCount/${widget.effectiveCaptureConfig.guidanceStabilityFrames}',
        'top=${quality.topPredictionsSummary()}',
      ].join(' | '),
    );
  }

  String _messageForQuality(DocumentQuality quality) {
    switch (quality) {
      case DocumentQuality.good:
        return 'Hold steady for capture.';
      case DocumentQuality.blurry:
        return 'Hold still for a clearer capture.';
      case DocumentQuality.glare:
        return 'Tilt slightly to reduce glare.';
      case DocumentQuality.dark:
        return 'Move to better lighting.';
      case DocumentQuality.noDocument:
        return 'Place your ID fully inside the frame.';
    }
  }

  void _recordInference(double ms, {QualityResult? quality}) {
    _inferenceSamples++;
    _avgInferenceMs =
        ((_avgInferenceMs * (_inferenceSamples - 1)) + ms) / _inferenceSamples;

    _strideAdjustCounter++;
    if (_strideAdjustCounter >=
        widget.effectiveCaptureConfig.strideAdjustmentWindow) {
      if (_avgInferenceMs >
              widget.effectiveCaptureConfig.increaseStrideInferenceMs &&
          _frameStride < widget.effectiveCaptureConfig.maxFrameStride) {
        _frameStride++;
      } else if (_avgInferenceMs <
              widget.effectiveCaptureConfig.decreaseStrideInferenceMs &&
          _frameStride > widget.effectiveCaptureConfig.minFrameStride) {
        _frameStride--;
      }
      _strideAdjustCounter = 0;
    }

    if (_inferenceSamples % widget.effectiveCaptureConfig.performanceLogEvery ==
        0) {
      logPrint(
        [
          'DocQuality snapshot',
          'session=${_formatDuration(_sessionStopwatch.elapsed)}',
          'frame=$_frameCounter',
          'avg=${_avgInferenceMs.toStringAsFixed(1)}ms',
          'last=${ms.toStringAsFixed(1)}ms',
          'stride=$_frameStride',
          'guidance=${_lastGuidanceMessage ?? _messageForQuality(_activeGuidanceQuality ?? DocumentQuality.noDocument)}',
          if (quality != null) 'top=${quality.topPredictionsSummary()}',
        ].join(' | '),
      );
    }
  }

  void _logQualityTransition({
    required QualityResult quality,
    required DocumentQuality guidanceQuality,
    required String guidanceMessage,
    required double inferenceMs,
  }) {
    final rawChanged = quality.quality != _lastLoggedRawQuality;
    final guidanceChanged = guidanceQuality != _lastLoggedGuidanceQuality ||
        guidanceMessage != _lastGuidanceMessage;

    if (!rawChanged && !guidanceChanged) {
      return;
    }

    final now = _sessionStopwatch.elapsed;
    final sinceLast = now - _lastGuidanceTransitionAt;
    _lastGuidanceTransitionAt = now;
    _lastLoggedRawQuality = quality.quality;
    _lastLoggedGuidanceQuality = guidanceQuality;
    _lastGuidanceMessage = guidanceMessage;
    _lastGuidanceHoldLogged = false;

    final noDocumentConfidence =
        quality.probabilityForLabel('NO_DOCUMENT') * 100;
    final blurryConfidence = quality.probabilityForLabel('BLURRY') * 100;
    final darkConfidence = quality.probabilityForLabel('DARK') * 100;
    final glareConfidence = quality.probabilityForLabel('GLARE') * 100;
    final goodConfidence = quality.probabilityForLabel('GOOD') * 100;

    logPrint(
      [
        'DocQuality transition',
        'session=${_formatDuration(now)}',
        'since_last=${_formatDuration(sinceLast)}',
        'frame=$_frameCounter',
        'infer=${inferenceMs.toStringAsFixed(1)}ms',
        'raw=${quality.quality.name}:${(quality.confidence * 100).toStringAsFixed(1)}%',
        'guidance=${guidanceQuality.name}',
        'message="$guidanceMessage"',
        'top=${quality.topPredictionsSummary()}',
        'probs[good=${goodConfidence.toStringAsFixed(1)} blur=${blurryConfidence.toStringAsFixed(1)} glare=${glareConfidence.toStringAsFixed(1)} dark=${darkConfidence.toStringAsFixed(1)} nodoc=${noDocumentConfidence.toStringAsFixed(1)}]',
      ].join(' | '),
    );
  }

  void _handleAutoCapture({
    required QualityResult quality,
    required bool allowsQualityAcceptance,
  }) {
    if (!widget.effectiveCaptureConfig.autoCaptureEnabled) {
      _autoCaptureTimer?.cancel();
      ref.read(documentCaptureUiProvider.notifier).setAutoCapturing(false);
      return;
    }

    final autoCaptureReady = _usesQualityGate
        ? allowsQualityAcceptance
        : quality.guidanceQuality == DocumentQuality.good;

    if (autoCaptureReady) {
      if (_autoCaptureTimer?.isActive ?? false) return;
      ref.read(documentCaptureUiProvider.notifier).setAutoCapturing(true);
      ref
          .read(thesisDebugReportProvider.notifier)
          .markDocumentAutoCaptureTriggered();
      _autoCaptureTimer =
          Timer(widget.effectiveCaptureConfig.autoCaptureHoldDuration, () {
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
        ref
            .read(thesisDebugReportProvider.notifier)
            .recordDocumentFailure('No document detected. Try again.');
        HapticFeedback.lightImpact();
        await _resumePreviewIfNeeded();
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
      ref.read(thesisDebugReportProvider.notifier).recordDocumentCapture(
            detected: true,
            documentPath: file.path,
            normalizedPath: normalized.path,
            statusMessage: 'Document detected. Looks good!',
          );
      HapticFeedback.mediumImpact();

      _isNavigatingToSelfie = true;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SelfieCaptureStep(
            captureBundle: KycCaptureBundle(documentPath: normalized.path),
          ),
        ),
      );
      if (!mounted) return;
      _isNavigatingToSelfie = false;
      await _resumeCameraAfterReturn();
    } catch (e) {
      if (!mounted) return;
      _isNavigatingToSelfie = false;
      notifier.setError('Capture failed. Please try again.');
      ref
          .read(thesisDebugReportProvider.notifier)
          .recordDocumentFailure('Capture failed. Please try again.');
      ToastUtil.showErrorToast('Document capture failed. Try again.');
    } finally {
      if (mounted) {
        notifier.setDetecting(false);
        if (_controller != null &&
            !_isStreaming &&
            !_isNavigatingToSelfie &&
            !_controller!.value.isTakingPicture) {
          await _startImageStream();
        }
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

                      if (uiState.isPermissionDenied ||
                          uiState.isPermanentlyDenied) {
                        return _PermissionStateCard(
                          permanentlyDenied: uiState.isPermanentlyDenied,
                          onRetry: _retryCameraSetup,
                        );
                      }

                      if (uiState.cameraErrorMessage != null) {
                        return _CameraErrorCard(
                          message: uiState.cameraErrorMessage!,
                          onRetry: _retryCameraSetup,
                        );
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
                          DocumentOverlayWidget(
                            visible: !uiState.documentDetected,
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
                text: uiState.isPermissionDenied ||
                        uiState.cameraErrorMessage != null
                    ? 'Retry camera'
                    : uiState.documentDetected
                        ? 'Recapture Document'
                    : (uiState.isDetecting
                        ? 'Detecting...'
                        : 'Capture Document'),
                enabled: uiState.isPermissionDenied ||
                        uiState.cameraErrorMessage != null
                    ? true
                    : uiState.documentDetected
                        ? true
                    : !uiState.isDetecting &&
                        (_usesQualityGate ? uiState.isQualityGood : true),
                onTap: uiState.isPermissionDenied ||
                        uiState.cameraErrorMessage != null
                    ? _retryCameraSetup
                    : uiState.documentDetected
                        ? _startRecaptureFlow
                        : _captureAndDetect,
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.s8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _pendingDebugSampleExport = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Next live quality inference will be exported.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Export Live Quality Sample'),
                ),
              ),
            ],
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

  Future<void> _retryCameraSetup() async {
    _autoCaptureTimer?.cancel();
    _isProcessingFrame = false;
    _pendingGuidanceQuality = null;
    _pendingGuidanceCount = 0;
    _activeGuidanceQuality = null;
    _lastGuidanceTransitionAt = Duration.zero;
    _lastGuidanceMessage = null;
    _lastLoggedRawQuality = null;
    _lastLoggedGuidanceQuality = null;
    _lastGuidanceHoldLogged = false;
    await _pauseCamera();
    await _disposeController();
    if (!mounted) return;
    setState(() {
      _initializeFuture = _ensureCameraInitialized();
    });
  }

  Future<void> _resumeCameraAfterReturn() async {
    _autoCaptureTimer?.cancel();
    _isProcessingFrame = false;
    _isStreaming = false;
    _pendingGuidanceQuality = null;
    _pendingGuidanceCount = 0;
    _activeGuidanceQuality = null;
    _lastGuidanceTransitionAt = Duration.zero;
    _lastGuidanceMessage = null;
    _lastLoggedRawQuality = null;
    _lastLoggedGuidanceQuality = null;
    _lastGuidanceHoldLogged = false;
    ref.read(documentCaptureUiProvider.notifier)
      ..setStatus('Document detected. Looks good!')
      ..setDocumentDetected(true)
      ..setAutoCapturing(false)
      ..setDetecting(false)
      ..clearError();
    await _resumePreviewIfNeeded();
  }

  Future<void> _startRecaptureFlow() async {
    _autoCaptureTimer?.cancel();
    _isProcessingFrame = false;
    _pendingGuidanceQuality = null;
    _pendingGuidanceCount = 0;
    _activeGuidanceQuality = null;
    _lastGuidanceTransitionAt = Duration.zero;
    _lastGuidanceMessage = null;
    _lastLoggedRawQuality = null;
    _lastLoggedGuidanceQuality = null;
    _lastGuidanceHoldLogged = false;
    ref.read(documentCaptureUiProvider.notifier)
      ..setStatus('Align your ID inside the frame.')
      ..setDocumentDetected(false)
      ..setAutoCapturing(false)
      ..setDetecting(false)
      ..clearError();
    await _resumeCamera();
  }

  Map<String, dynamic> _documentConfigToJson(DocumentCaptureConfig config) {
    return {
      'resolution_preset': config.resolutionPreset.name,
      'image_format_group': config.imageFormatGroup.name,
      'initial_frame_stride': config.initialFrameStride,
      'min_frame_stride': config.minFrameStride,
      'max_frame_stride': config.maxFrameStride,
      'stride_adjustment_window': config.strideAdjustmentWindow,
      'increase_stride_inference_ms': config.increaseStrideInferenceMs,
      'decrease_stride_inference_ms': config.decreaseStrideInferenceMs,
      'auto_capture_hold_ms': config.autoCaptureHoldDuration.inMilliseconds,
      'auto_capture_enabled': config.autoCaptureEnabled,
      'performance_log_every': config.performanceLogEvery,
      'guidance_stability_frames': config.guidanceStabilityFrames,
      'quality_mode': config.qualityMode.name,
    };
  }

  bool get _usesQualityGate =>
      widget.effectiveCaptureConfig.qualityMode ==
      DocumentQualityMode.qualityGate;

  bool _allowsQualityAcceptance(QualityResult quality) {
    if (!_usesQualityGate) {
      return true;
    }
    return quality.isGood;
  }

  String _cameraErrorMessage(
    String code,
    String? description, {
    required String lensLabel,
  }) {
    if (code == 'CameraAccessDenied') {
      return 'Camera access was denied by the device.';
    }
    final details = description?.toLowerCase() ?? '';
    if (details.contains('no supported surface combination') ||
        details.contains('may be attempting to bind too many use cases')) {
      return 'Camera session conflicted during startup. Retry camera to try again.';
    }
    if (details.contains('no camera') || details.contains('not available')) {
      return 'No $lensLabel camera is available on this device.';
    }
    return 'Unable to start the $lensLabel camera.';
  }

  String _formatDuration(Duration duration) {
    final totalMs = duration.inMilliseconds;
    final seconds = totalMs ~/ 1000;
    final millis = totalMs % 1000;
    return '$seconds.${(millis ~/ 10).toString().padLeft(2, '0')}s';
  }

  bool get _shouldProcessLiveQualityFrames {
    if (!mounted) return false;
    if (_isNavigatingToSelfie) return false;
    if (!_isStreaming) return false;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return false;
    if (controller.value.isTakingPicture) return false;
    final uiState = ref.read(documentCaptureUiProvider);
    if (uiState.isDetecting) return false;
    return true;
  }

  Future<void> _resumePreviewIfNeeded() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isPreviewPaused) return;
    try {
      await controller.resumePreview();
    } on CameraException catch (error) {
      logPrint('Document camera resume preview ignored: ${error.code}');
    } catch (_) {
      logPrint('Document camera resume preview ignored.');
    }
  }
}

class _PermissionStateCard extends StatelessWidget {
  const _PermissionStateCard({
    required this.permanentlyDenied,
    required this.onRetry,
  });

  final bool permanentlyDenied;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pad16,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Camera permission needed',
              style: context.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              permanentlyDenied
                  ? 'Enable camera access in your phone settings to continue document capture.'
                  : 'Allow camera access to continue document capture.',
              style: context.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: ButtonWidget(
                text: permanentlyDenied ? 'Open settings' : 'Try again',
                onTap: permanentlyDenied ? openAppSettings : onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraErrorCard extends StatelessWidget {
  const _CameraErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pad16,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Camera unavailable',
              style: context.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              message,
              style: context.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: ButtonWidget(
                text: 'Retry camera',
                onTap: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
