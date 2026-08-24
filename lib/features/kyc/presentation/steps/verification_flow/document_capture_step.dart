import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:kyc_verification_app_demo/core/camera/camera_lifecycle_coordinator.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/ml/quality_model.dart';
import 'package:kyc_verification_app_demo/core/ml/quality_isolate.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/utils/app_assets.dart';
import 'package:kyc_verification_app_demo/core/utils/logger.dart';
import 'package:kyc_verification_app_demo/core/utils/toast_utils.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/services/document_quality_debug_exporter.dart';
import '../../../data/services/document_capture_service.dart';
import '../../../data/services/document_quality_guidance_service.dart';
import '../../../domain/models/document_capture_request.dart';
import '../../../domain/models/document_capture_result.dart';
import '../../../domain/models/document_quality_guidance_request.dart';
import '../../../domain/models/kyc_capture_bundle.dart';
import '../../controllers/document_capture_runtime_controller.dart';
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
  late final CameraLifecycleCoordinator _cameraLifecycle;
  late final ObjectDetector _objectDetector;
  late final DocumentCaptureService _documentCaptureService;
  late final DocumentQualityGuidanceService _guidanceService;
  late final DocumentCaptureRuntimeController _runtimeController;
  Timer? _autoCaptureTimer;
  QualityIsolate? _qualityIsolate;
  KycCaptureBundle? _lastCapturedBundle;
  QualityDebugArtifacts? _latestQualityDebugArtifacts;
  QualityResult? _latestQualityResult;
  DocumentQuality? _latestGuidanceQuality;
  String? _latestGuidanceMessage;
  double? _latestInferenceMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraLifecycle = CameraLifecycleCoordinator(
      logPrefix: 'Document camera',
      logger: logPrint,
    );
    _documentCaptureService = const DocumentCaptureService();
    _guidanceService = DocumentQualityGuidanceService();
    _runtimeController = DocumentCaptureRuntimeController(
      initialFrameStride: widget.effectiveCaptureConfig.initialFrameStride,
    )..startSession();
    _runtimeController.setPendingDebugSampleExport(kDebugMode);
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
    final controller = _controller;
    _controller = null;
    await _cameraLifecycle.disposeController(controller);
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
    _cameraLifecycle.markDisposed();
    WidgetsBinding.instance.removeObserver(this);
    _autoCaptureTimer?.cancel();
    unawaited(_disposeController());
    _objectDetector.close();
    _qualityIsolate?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _cameraLifecycle.isDisposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_resumeCamera());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_pauseCamera());
        break;
    }
  }

  Future<void> _pauseCamera() {
    return _cameraLifecycle.queueTransition(_pauseCameraInternal);
  }

  Future<void> _pauseCameraInternal() async {
    _autoCaptureTimer?.cancel();
    _runtimeController.resetTransientState(
      initialFrameStride: widget.effectiveCaptureConfig.initialFrameStride,
    );
    await _cameraLifecycle.stopImageStreamImmediate(_controller);
  }

  Future<void> _resumeCamera() {
    return _cameraLifecycle.queueTransition(_resumeCameraInternal);
  }

  Future<void> _resumeCameraInternal() async {
    if (!_cameraLifecycle.isRouteActive) return;
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
    _cameraLifecycle.syncStreamingFromController(_controller);
    if (!_cameraLifecycle.isStreaming) {
      await _startImageStreamInternal();
    }
  }

  Future<void> _startImageStream() {
    return _cameraLifecycle.startImageStream(
      controller: _controller,
      onImage: _onCameraImage,
    );
  }

  Future<void> _startImageStreamInternal() async {
    await _cameraLifecycle.startImageStreamImmediate(
      controller: _controller,
      onImage: _onCameraImage,
    );
  }

  Future<void> _stopImageStreamInternal() async {
    await _cameraLifecycle.stopImageStreamImmediate(_controller);
  }

  Future<void> _processPayload(Map<String, Object?> payload) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (!_shouldProcessLiveQualityFrames) return;
      final inference = await _qualityIsolate?.predictPayload(
        payload,
        includeDebugArtifacts:
            kDebugMode || _runtimeController.pendingDebugSampleExport,
      );
      if (!mounted) return;
      if (!_shouldProcessLiveQualityFrames) return;
      if (inference == null) return;
      final quality = QualityModel.fromProbabilities(inference.probabilities);
      final guidance = _guidanceService.evaluate(
        DocumentQualityGuidanceRequest(
          quality: quality,
          config: widget.effectiveCaptureConfig,
          usesQualityGate: _usesQualityGate,
        ),
      );
      if (guidance.pendingQuality != null &&
          guidance.activeQuality != null &&
          !guidance.shouldLogHold) {
        _logGuidanceHold(
          quality: quality,
          activeQuality: guidance.activeQuality!,
          pendingQuality: guidance.pendingQuality!,
        );
      }
      _logQualityTransition(
        quality: quality,
        guidanceQuality: guidance.guidanceQuality,
        guidanceMessage: guidance.message,
        inferenceMs: stopwatch.elapsedMicroseconds / 1000,
      );
      if (kDebugMode && inference.debugArtifacts != null) {
        _latestQualityDebugArtifacts = inference.debugArtifacts;
        _latestQualityResult = quality;
        _latestGuidanceQuality = guidance.guidanceQuality;
        _latestGuidanceMessage = guidance.message;
        _latestInferenceMs = stopwatch.elapsedMicroseconds / 1000;
      }
      ref.read(documentCaptureUiProvider.notifier).updateQuality(
            message: guidance.message,
            confidence: quality.confidence,
            isGood: guidance.allowsQualityAcceptance,
          );
      ref.read(thesisDebugReportProvider.notifier).recordDocumentQuality(
            statusMessage: guidance.message,
            qualityLabel: quality.quality.name,
            confidence: quality.confidence,
            accepted: guidance.allowsQualityAcceptance,
            averageInferenceMs: _runtimeController.avgInferenceMs == 0
                ? stopwatch.elapsedMicroseconds / 1000
                : _runtimeController.avgInferenceMs,
            inferenceSamples: _runtimeController.inferenceSamples,
            frameStride: _runtimeController.frameStride,
          );

      _handleAutoCapture(
        autoCaptureReady: guidance.autoCaptureReady,
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
      _runtimeController.finishFrameProcessing();
    }
  }

  void _logGuidanceHold({
    required QualityResult quality,
    required DocumentQuality activeQuality,
    required DocumentQuality pendingQuality,
  }) {
    _guidanceService.markHoldLogged();
    logPrint(
      [
        'DocQuality hold',
        'session=${_runtimeController.formatDuration(_runtimeController.sessionElapsed)}',
        'frame=${_runtimeController.frameCounter}',
        'raw=${quality.quality.name}:${(quality.confidence * 100).toStringAsFixed(1)}%',
        'active=${activeQuality.name}',
        'pending=${pendingQuality.name}',
        'pending_count=${_guidanceService.pendingGuidanceCount}/${widget.effectiveCaptureConfig.guidanceStabilityFrames}',
        'top=${quality.topPredictionsSummary()}',
      ].join(' | '),
    );
  }

  void _recordInference(double ms, {QualityResult? quality}) {
    _runtimeController.recordInference(
      ms: ms,
      config: widget.effectiveCaptureConfig,
    );

    if (_runtimeController.inferenceSamples %
            widget.effectiveCaptureConfig.performanceLogEvery ==
        0) {
      logPrint(
        [
          'DocQuality snapshot',
          'session=${_runtimeController.formatDuration(_runtimeController.sessionElapsed)}',
          'frame=${_runtimeController.frameCounter}',
          'avg=${_runtimeController.avgInferenceMs.toStringAsFixed(1)}ms',
          'last=${ms.toStringAsFixed(1)}ms',
          'stride=${_runtimeController.frameStride}',
          'guidance=${_guidanceService.lastGuidanceMessage ?? 'Place your ID fully inside the frame.'}',
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
    final rawChanged = quality.quality != _guidanceService.lastLoggedRawQuality;
    final guidanceChanged =
        guidanceQuality != _guidanceService.lastLoggedGuidanceQuality ||
            guidanceMessage != _guidanceService.lastGuidanceMessage;

    if (!rawChanged && !guidanceChanged) {
      return;
    }

    final now = _runtimeController.sessionElapsed;
    final sinceLast = now - _runtimeController.lastGuidanceTransitionAt;
    _runtimeController.markTransitionLogged(now);
    _guidanceService.markTransitionLogged(
      quality: quality,
      guidanceQuality: guidanceQuality,
      guidanceMessage: guidanceMessage,
    );

    final noDocumentConfidence =
        quality.probabilityForLabel('NO_DOCUMENT') * 100;
    final blurryConfidence = quality.probabilityForLabel('BLURRY') * 100;
    final darkConfidence = quality.probabilityForLabel('DARK') * 100;
    final glareConfidence = quality.probabilityForLabel('GLARE') * 100;
    final goodConfidence = quality.probabilityForLabel('GOOD') * 100;

    logPrint(
      [
        'DocQuality transition',
        'session=${_runtimeController.formatDuration(now)}',
        'since_last=${_runtimeController.formatDuration(sinceLast)}',
        'frame=${_runtimeController.frameCounter}',
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
    required bool autoCaptureReady,
  }) {
    if (!widget.effectiveCaptureConfig.autoCaptureEnabled) {
      _autoCaptureTimer?.cancel();
      ref.read(documentCaptureUiProvider.notifier).setAutoCapturing(false);
      return;
    }

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
      await _stopImageStreamInternal();
      final result = await _documentCaptureService.captureAndNormalize(
        DocumentCaptureRequest(
          controller: _controller!,
          objectDetector: _objectDetector,
          captureConfig: widget.effectiveCaptureConfig,
        ),
      );
      if (!mounted) return;
      final statusMessage = result.usedGuideCropFallback
          ? 'Document captured from the guide frame.'
          : 'Document detected. Looks good!';
      _lastCapturedBundle =
          KycCaptureBundle(documentPath: result.normalizedPath);
      notifier.setCapturedDocument(
        previewPath: result.originalPath,
        statusMessage: statusMessage,
      );
      ref.read(thesisDebugReportProvider.notifier).recordDocumentCapture(
            detected: true,
            documentPath: result.originalPath,
            normalizedPath: result.normalizedPath,
            statusMessage: statusMessage,
          );
      await _exportAutomaticDocumentQualityDebugSample();
      logPrint(
        result.captureSource == DocumentCaptureSource.guideFallback
            ? 'Document capture used centered guide crop fallback after detector miss.'
            : 'Document capture used object detector bounding box.',
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;

      _runtimeController.setNavigatingToSelfie(true);
      _cameraLifecycle.markRouteActive(false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SelfieCaptureStep(
            captureBundle: _lastCapturedBundle!,
          ),
        ),
      );
      if (!mounted) return;
      _runtimeController.setNavigatingToSelfie(false);
      _cameraLifecycle.markRouteActive(true);
      _restoreCapturedStateAfterReturn(statusMessage: statusMessage);
    } catch (e) {
      if (!mounted) return;
      _runtimeController.setNavigatingToSelfie(false);
      _cameraLifecycle.markRouteActive(true);
      notifier.setError('Capture failed. Please try again.');
      ref
          .read(thesisDebugReportProvider.notifier)
          .recordDocumentFailure('Capture failed. Please try again.');
      ToastUtil.showErrorToast('Document capture failed. Try again.');
    } finally {
      if (mounted) {
        notifier.setDetecting(false);
        final latestUiState = ref.read(documentCaptureUiProvider);
        if (_controller != null &&
            !_cameraLifecycle.isStreaming &&
            !_runtimeController.isNavigatingToSelfie &&
            !_controller!.value.isTakingPicture &&
            !latestUiState.documentDetected) {
          await _startImageStream();
        }
      }
    }
  }

  Future<void> _exportAutomaticDocumentQualityDebugSample() async {
    if (!kDebugMode) return;
    final debugArtifacts = _latestQualityDebugArtifacts;
    final quality = _latestQualityResult;
    final guidanceQuality = _latestGuidanceQuality;
    final guidanceMessage = _latestGuidanceMessage;
    final inferenceMs = _latestInferenceMs;
    if (debugArtifacts == null ||
        quality == null ||
        guidanceQuality == null ||
        guidanceMessage == null ||
        inferenceMs == null) {
      return;
    }

    final runId = ref.read(thesisDebugReportProvider).runId;
    final exportResult = await ref
        .read(documentQualityDebugExporterProvider)
        .exportLiveSample(
          runId: runId,
          quality: quality,
          displayedGuidance: guidanceQuality,
          guidanceMessage: guidanceMessage,
          inferenceMs: inferenceMs,
          frameNumber: _runtimeController.frameCounter,
          frameStride: _runtimeController.frameStride,
          documentConfig: _documentConfigToJson(widget.effectiveCaptureConfig),
          debugArtifacts: debugArtifacts,
        );
    ref
        .read(thesisDebugReportProvider.notifier)
        .recordDocumentQualityDebugSample(exportResult);
    logPrint(
      'Document quality debug sample exported to ${exportResult.directoryPath}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(documentCaptureUiProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _cameraLifecycle.markRouteActive(false);
          unawaited(_pauseCamera());
        }
      },
      child: Scaffold(
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
                          return const Center(
                              child: CircularProgressIndicator());
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

                        if (uiState.documentDetected &&
                            uiState.capturedPreviewPath != null) {
                          return Image.file(
                            File(uiState.capturedPreviewPath!),
                            fit: BoxFit.cover,
                          );
                        }

                        return Center(
                          child: CameraPreview(
                            _controller!,
                            child: DocumentOverlayWidget(
                              visible: !uiState.documentDetected,
                              captureConfig: widget.effectiveCaptureConfig,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              if (uiState.documentDetected) ...[
                SizedBox(
                  width: double.infinity,
                  child: ButtonWidget(
                    text: 'Continue',
                    enabled: !uiState.isDetecting,
                    onTap: _continueWithCapturedDocument,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: uiState.isDetecting ? null : _startRecaptureFlow,
                    child: const Text('Recapture Document'),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ButtonWidget(
                    text: uiState.isPermissionDenied ||
                            uiState.cameraErrorMessage != null
                        ? 'Retry camera'
                        : (uiState.isDetecting
                            ? 'Detecting...'
                            : 'Capture Document'),
                    enabled: uiState.isPermissionDenied ||
                            uiState.cameraErrorMessage != null
                        ? true
                        : !uiState.isDetecting &&
                            (_usesQualityGate ? uiState.isQualityGood : true),
                    onTap: uiState.isPermissionDenied ||
                            uiState.cameraErrorMessage != null
                        ? _retryCameraSetup
                        : _captureAndDetect,
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
    _cameraLifecycle.markRouteActive(true);
    _autoCaptureTimer?.cancel();
    _runtimeController.resetTransientState(
      initialFrameStride: widget.effectiveCaptureConfig.initialFrameStride,
    );
    _guidanceService.reset();
    await _pauseCamera();
    await _disposeController();
    if (!mounted) return;
    setState(() {
      _initializeFuture = _ensureCameraInitialized();
    });
  }

  void _restoreCapturedStateAfterReturn({
    required String statusMessage,
  }) {
    _autoCaptureTimer?.cancel();
    _runtimeController.resetTransientState(
      initialFrameStride: widget.effectiveCaptureConfig.initialFrameStride,
    );
    _cameraLifecycle.syncStreamingFromController(null);
    _guidanceService.reset();
    final previewPath = ref.read(documentCaptureUiProvider).capturedPreviewPath;
    if (previewPath != null) {
      ref.read(documentCaptureUiProvider.notifier).setCapturedDocument(
            previewPath: previewPath,
            statusMessage: statusMessage,
          );
    }
  }

  Future<void> _startRecaptureFlow() async {
    _cameraLifecycle.markRouteActive(true);
    _autoCaptureTimer?.cancel();
    _runtimeController.resetTransientState(
      initialFrameStride: widget.effectiveCaptureConfig.initialFrameStride,
    );
    _lastCapturedBundle = null;
    _guidanceService.reset();
    ref.read(documentCaptureUiProvider.notifier)
      ..setStatus('Align your ID inside the frame.')
      ..clearCapturedDocument()
      ..setAutoCapturing(false)
      ..setDetecting(false)
      ..clearError();
    await _pauseCamera();
    await _disposeController();
    if (!mounted) return;
    setState(() {
      _initializeFuture = _ensureCameraInitialized();
    });
  }

  Future<void> _continueWithCapturedDocument() async {
    final bundle = _lastCapturedBundle;
    if (bundle == null) {
      await _startRecaptureFlow();
      return;
    }

    final statusMessage = ref.read(documentCaptureUiProvider).statusMessage;
    _runtimeController.setNavigatingToSelfie(true);
    _cameraLifecycle.markRouteActive(false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelfieCaptureStep(captureBundle: bundle),
      ),
    );
    if (!mounted) return;
    _runtimeController.setNavigatingToSelfie(false);
    _cameraLifecycle.markRouteActive(true);
    _restoreCapturedStateAfterReturn(statusMessage: statusMessage);
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
      'guide_width_factor': config.guideWidthFactor,
      'guide_aspect_ratio': config.guideAspectRatio,
      'guide_max_height_factor': config.guideMaxHeightFactor,
      'quality_crop_scale': config.qualityCropScale,
    };
  }

  bool get _usesQualityGate =>
      widget.effectiveCaptureConfig.qualityMode ==
      DocumentQualityMode.qualityGate;

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

  bool get _shouldProcessLiveQualityFrames {
    if (!mounted) return false;
    if (_cameraLifecycle.isDisposed) return false;
    if (!_cameraLifecycle.isRouteActive) return false;
    if (_runtimeController.isNavigatingToSelfie) return false;
    if (!_cameraLifecycle.isStreaming) return false;
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

  void _onCameraImage(CameraImage cameraImage) {
    if (!mounted) return;
    if (!_runtimeController.shouldProcessNextFrame()) return;
    final payload = _qualityIsolate?.buildPayload(cameraImage);
    if (payload == null) {
      _runtimeController.finishFrameProcessing();
      return;
    }
    unawaited(
      _processPayload(
        augmentQualityPayloadWithGuideConfig(
          payload,
          guideWidthFactor: widget.effectiveCaptureConfig.guideWidthFactor,
          guideAspectRatio: widget.effectiveCaptureConfig.guideAspectRatio,
          guideMaxHeightFactor:
              widget.effectiveCaptureConfig.guideMaxHeightFactor,
          qualityCropScale: widget.effectiveCaptureConfig.qualityCropScale,
        ),
      ),
    );
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
