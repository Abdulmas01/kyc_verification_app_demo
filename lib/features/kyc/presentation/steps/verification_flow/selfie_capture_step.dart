import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    show Face, FaceDetector, FaceDetectorMode, FaceDetectorOptions, InputImage;
import 'package:kyc_verification_app_demo/core/camera/camera_lifecycle_coordinator.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/utils/logger.dart';
import 'package:kyc_verification_app_demo/core/utils/toast_utils.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/services/mobile_liveness_shadow_service.dart';
import '../../../data/services/selfie_input_image_service.dart';
import '../../../data/services/selfie_liveness_challenge_service.dart';
import '../../../domain/models/kyc_capture_bundle.dart';
import '../../../domain/models/mobile_liveness_shadow_request.dart';
import '../../../domain/models/selfie_input_image_request.dart';
import '../../../domain/models/selfie_liveness_challenge_request.dart';
import '../../../domain/models/selfie_liveness_decision.dart';
import '../../controllers/selfie_capture_ui_notifier.dart';
import '../../controllers/thesis_debug_report_notifier.dart';
import '../../models/kyc_capture_config.dart';
import '../../models/selfie_capture_ui_state.dart';
import 'processing_step.dart';

class SelfieCaptureStep extends ConsumerStatefulWidget {
  const SelfieCaptureStep({
    super.key,
    required this.captureBundle,
    this.captureProfile,
    this.livenessConfig = const SelfieLivenessConfig.balanced(),
  });

  static const String path = '/kyc/selfie';

  final KycCaptureBundle captureBundle;
  final KycCaptureProfile? captureProfile;
  final SelfieLivenessConfig livenessConfig;

  SelfieLivenessConfig get effectiveLivenessConfig =>
      captureProfile?.selfieLiveness ?? livenessConfig;

  @override
  ConsumerState<SelfieCaptureStep> createState() => _SelfieCaptureStepState();
}

class _SelfieCaptureStepState extends ConsumerState<SelfieCaptureStep>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  Future<void>? _cameraSetupFuture;
  late final CameraLifecycleCoordinator _cameraLifecycle;
  late final SelfieInputImageService _selfieInputImageService;
  late final SelfieLivenessChallengeService _challengeService;
  late final MobileLivenessShadowService _mobileLivenessShadowService;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  bool _blinkPrimed = false;
  bool _capturingSelfie = false;
  int _frameCounter = 0;
  int _analysisFailureCount = 0;
  Timer? _challengeTimeoutTimer;

  late final FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraLifecycle = CameraLifecycleCoordinator(
      logPrefix: 'Selfie camera',
      logger: logPrint,
    );
    _selfieInputImageService = const SelfieInputImageService();
    _challengeService = const SelfieLivenessChallengeService();
    _mobileLivenessShadowService = const MobileLivenessShadowService();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: true,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initializeFuture = Future.value();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(thesisDebugReportProvider.notifier).attachSelfieConfig(
            _selfieConfigToJson(widget.effectiveLivenessConfig),
          );
      ref
          .read(thesisDebugReportProvider.notifier)
          .configureMobileLivenessShadow(
            enabled: widget.effectiveLivenessConfig.mobileShadow.enabled,
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
    _isStreaming = false;
    await _cameraLifecycle.disposeController(controller);
  }

  Future<void> _initCamera() async {
    final notifier = ref.read(selfieCaptureUiProvider.notifier);
    notifier.resetFlow();

    final permission = await Permission.camera.request();
    if (!mounted) return;

    if (!permission.isGranted) {
      ref.read(thesisDebugReportProvider.notifier).recordSelfieStatus(
            errorMessage:
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

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        widget.effectiveLivenessConfig.resolutionPreset,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? widget.effectiveLivenessConfig.iosImageFormatGroup
            : widget.effectiveLivenessConfig.androidImageFormatGroup,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
      });
      notifier.setCameraReady(true);
      _scheduleChallengeTimeout();
      await _startImageStream();
    } on CameraException catch (e) {
      final userMessage = _cameraErrorMessage(
        e.code,
        e.description,
        lensLabel: 'front',
      );
      ref.read(thesisDebugReportProvider.notifier).recordSelfieStatus(
            errorMessage: e.description ?? userMessage,
          );
      notifier.setCameraError(userMessage);
    } catch (_) {
      ref.read(thesisDebugReportProvider.notifier).recordSelfieStatus(
            errorMessage: 'Unable to start the front camera.',
          );
      notifier.setCameraError('Unable to start the front camera.');
    }
  }

  @override
  void dispose() {
    _cameraLifecycle.markDisposed();
    WidgetsBinding.instance.removeObserver(this);
    _challengeTimeoutTimer?.cancel();
    unawaited(_disposeController());
    _faceDetector.close();
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

  Future<void> _pauseCamera() async {
    await _cameraLifecycle.queueTransition(_pauseCameraInternal);
  }

  Future<void> _pauseCameraInternal() async {
    _challengeTimeoutTimer?.cancel();
    _isProcessingFrame = false;
    await _cameraLifecycle.stopImageStreamImmediate(_controller);
  }

  Future<void> _resumeCamera() async {
    await _cameraLifecycle.queueTransition(_resumeCameraInternal);
  }

  Future<void> _resumeCameraInternal() async {
    if (!_cameraLifecycle.isRouteActive) return;
    final uiState = ref.read(selfieCaptureUiProvider);
    if (uiState.isPermissionDenied || uiState.isPermanentlyDenied) {
      return;
    }
    if (_controller == null || !(_controller?.value.isInitialized ?? false)) {
      _initializeFuture = _ensureCameraInitialized();
      if (mounted) setState(() {});
      return;
    }
    _cameraLifecycle.syncStreamingFromController(_controller);
    _isStreaming = _cameraLifecycle.isStreaming;
    if (!_isStreaming && !_capturingSelfie) {
      _scheduleChallengeTimeout();
      await _startImageStreamInternal();
    }
  }

  Future<void> _startImageStream() async {
    await _cameraLifecycle.startImageStream(
      controller: _controller,
      onImage: _onCameraImage,
    );
  }

  Future<void> _startImageStreamInternal() async {
    await _cameraLifecycle.startImageStreamImmediate(
      controller: _controller,
      onImage: _onCameraImage,
    );
    _isStreaming = _cameraLifecycle.isStreaming;
  }

  Future<void> _stopImageStream() async {
    await _cameraLifecycle.stopImageStream(_controller);
    _isStreaming = _cameraLifecycle.isStreaming;
  }

  Future<void> _stopImageStreamInternal() async {
    await _cameraLifecycle.stopImageStreamImmediate(_controller);
    _isStreaming = _cameraLifecycle.isStreaming;
  }

  Future<void> _processCameraFrame(CameraImage cameraImage) async {
    if (!_cameraLifecycle.isRouteActive || _cameraLifecycle.isDisposed) {
      _isProcessingFrame = false;
      return;
    }
    final selfieCaptureUiNotifier = ref.read(selfieCaptureUiProvider.notifier);
    try {
      final controller = _controller;
      if (controller == null) return;
      final inputImage = _selfieInputImageService.build(
        SelfieInputImageRequest(
          controller: controller,
          image: cameraImage,
        ),
      );
      if (inputImage == null) {
        _analysisFailureCount++;
        if (_analysisFailureCount <= 3 || _analysisFailureCount % 10 == 0) {
          logPrint(
            'Selfie frame skipped: unsupported camera image format '
            '(format=${cameraImage.format.raw}, planes=${cameraImage.planes.length}).',
          );
        }
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      _analysisFailureCount = 0;
      if (!mounted) return;

      if (faces.isEmpty) {
        _blinkPrimed = false;
        selfieCaptureUiNotifier.setFaceDetected(false);
        ref.read(thesisDebugReportProvider.notifier).recordSelfieFaceDetected(
              false,
            );
        selfieCaptureUiNotifier.setChallengeMessage(
          'Center your face in the oval to continue.',
        );
        ref.read(thesisDebugReportProvider.notifier).recordSelfieStatus(
              statusMessage: 'Center your face in the oval to continue.',
            );
        return;
      }

      if (faces.length > 1) {
        selfieCaptureUiNotifier.setFaceDetected(false);
        ref.read(thesisDebugReportProvider.notifier).recordSelfieFaceDetected(
              false,
            );
        selfieCaptureUiNotifier.setError(
          statusMessage: 'Only one face should be visible.',
          errorMessage: 'Multiple faces detected. Please continue alone.',
        );
        ref.read(thesisDebugReportProvider.notifier).recordSelfieStatus(
              statusMessage: 'Only one face should be visible.',
              errorMessage: 'Multiple faces detected. Please continue alone.',
            );
        return;
      }

      final face = faces.first;
      selfieCaptureUiNotifier.setFaceDetected(true);
      ref.read(thesisDebugReportProvider.notifier).recordSelfieFaceDetected(
            true,
          );
      await _applyChallengeDecision(face);
    } catch (error) {
      _analysisFailureCount++;
      if (_analysisFailureCount <= 3 || _analysisFailureCount % 10 == 0) {
        logPrint(
          'Selfie face analysis failed '
          '(count=$_analysisFailureCount, error=$error).',
        );
      }
      if (!mounted) return;
      selfieCaptureUiNotifier.setError(
        statusMessage: 'We could not read your face clearly.',
        errorMessage: 'Face analysis failed. Please try again.',
      );
      ref.read(thesisDebugReportProvider.notifier).recordSelfieStatus(
            statusMessage: 'We could not read your face clearly.',
            errorMessage: 'Face analysis failed. Please try again.',
          );
    } finally {
      _isProcessingFrame = false;
    }
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

  Future<void> _applyChallengeDecision(Face face) async {
    final selfieCaptureUiNotifier = ref.read(selfieCaptureUiProvider.notifier);
    final uiState = ref.read(selfieCaptureUiProvider);
    final decision = _challengeService.evaluate(
      SelfieLivenessChallengeRequest(
        face: face,
        uiState: uiState,
        config: widget.effectiveLivenessConfig,
        blinkPrimed: _blinkPrimed,
      ),
    );

    if (decision.primesBlink) {
      _blinkPrimed = true;
    }
    if (decision.resetsBlink) {
      _blinkPrimed = false;
    }

    switch (decision.type) {
      case SelfieLivenessDecisionType.waitForBetterLighting:
      case SelfieLivenessDecisionType.promptBlink:
      case SelfieLivenessDecisionType.promptTurnLeft:
      case SelfieLivenessDecisionType.promptTurnRight:
      case SelfieLivenessDecisionType.promptLookStraight:
        selfieCaptureUiNotifier.setChallengeMessage(
          decision.statusMessage ?? uiState.statusMessage,
          helperMessage: decision.helperMessage,
        );
        return;
      case SelfieLivenessDecisionType.blinkCompleted:
        selfieCaptureUiNotifier.markBlinkComplete();
        break;
      case SelfieLivenessDecisionType.turnLeftCompleted:
        selfieCaptureUiNotifier.markTurnLeftComplete();
        break;
      case SelfieLivenessDecisionType.turnRightCompleted:
        selfieCaptureUiNotifier.markTurnRightComplete();
        break;
      case SelfieLivenessDecisionType.readyToCapture:
        _challengeTimeoutTimer?.cancel();
        if (decision.completedChallengeKey != null) {
          ref
              .read(thesisDebugReportProvider.notifier)
              .recordChallengeCompleted(decision.completedChallengeKey!);
        }
        selfieCaptureUiNotifier.startAutoCapture();
        HapticFeedback.selectionClick();
        await _captureSelfie();
        return;
      case SelfieLivenessDecisionType.complete:
        return;
    }

    if (decision.completedChallengeKey != null) {
      ref
          .read(thesisDebugReportProvider.notifier)
          .recordChallengeCompleted(decision.completedChallengeKey!);
    }
    _scheduleChallengeTimeout();
    HapticFeedback.mediumImpact();
  }

  Future<void> _captureSelfie() async {
    final selfieCaptureUiNotifier = ref.read(selfieCaptureUiProvider.notifier);
    if (_controller == null || _capturingSelfie) return;
    _capturingSelfie = true;
    try {
      await _stopImageStreamInternal();
      selfieCaptureUiNotifier.startCapture();
      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;
      if (faces.isEmpty) {
        selfieCaptureUiNotifier.requestRedo(
          statusMessage: 'No face detected. Try again.',
          errorMessage: 'No face detected. Try again.',
          helperMessage:
              'Bring your face back into the oval and redo the check.',
        );
        ref.read(thesisDebugReportProvider.notifier).recordSelfieStatus(
              statusMessage: 'No face detected. Try again.',
              errorMessage: 'No face detected. Try again.',
              incrementRedo: true,
            );
        HapticFeedback.lightImpact();
        ToastUtil.showErrorToast('No face detected. Try again.');
        await _startImageStream();
        return;
      }

      selfieCaptureUiNotifier.completeFlow();
      ref
          .read(thesisDebugReportProvider.notifier)
          .recordSelfieCapture(file.path);
      await _runMobileLivenessShadowIfEnabled(file.path);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _cameraLifecycle.markRouteActive(false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProcessingStep(
            captureBundle: widget.captureBundle.copyWith(
              selfiePath: file.path,
            ),
          ),
        ),
      );
      if (!mounted) return;
      _cameraLifecycle.markRouteActive(true);
    } catch (e) {
      if (!mounted) return;
      selfieCaptureUiNotifier.requestRedo(
        statusMessage: 'Capture failed. Please try again.',
        errorMessage: 'Selfie capture failed. Try again.',
        helperMessage: 'Redo the liveness check and keep the phone steady.',
      );
      ref.read(thesisDebugReportProvider.notifier).recordSelfieStatus(
            statusMessage: 'Capture failed. Please try again.',
            errorMessage: 'Selfie capture failed. Try again.',
            incrementRedo: true,
          );
      HapticFeedback.lightImpact();
      ToastUtil.showErrorToast('Selfie capture failed. Try again.');
      await _startImageStreamInternal();
    } finally {
      _capturingSelfie = false;
      if (mounted && ref.read(selfieCaptureUiProvider).shouldRedo) {
        await _stopImageStreamInternal();
      }
    }
  }

  Future<void> _runMobileLivenessShadowIfEnabled(String selfiePath) async {
    final result = await _mobileLivenessShadowService.run(
      MobileLivenessShadowRequest(
        selfiePath: selfiePath,
        config: widget.effectiveLivenessConfig.mobileShadow,
      ),
    );
    if (result == null) {
      return;
    }

    if (result.isAvailable) {
      ref
          .read(thesisDebugReportProvider.notifier)
          .recordMobileLivenessShadowSuccess(
            score: result.score!,
            latencyMs: result.latencyMs!,
          );
      return;
    }

    ref
        .read(thesisDebugReportProvider.notifier)
        .recordMobileLivenessShadowUnavailable(
            result.errorMessage ?? 'Unknown');
  }

  void _scheduleChallengeTimeout() {
    _challengeTimeoutTimer?.cancel();
    _challengeTimeoutTimer = Timer(
      widget.effectiveLivenessConfig.challengeTimeout,
      () {
        if (!mounted || _capturingSelfie) return;
        final uiState = ref.read(selfieCaptureUiProvider);
        if (uiState.isChallengeComplete || uiState.shouldRedo) return;
        ref.read(selfieCaptureUiProvider.notifier).requestRedo(
              statusMessage: 'Liveness step timed out.',
              errorMessage: 'We could not confirm that step in time.',
              helperMessage: 'Tap redo and try the liveness check again.',
            );
        ref.read(thesisDebugReportProvider.notifier).recordSelfieStatus(
              statusMessage: 'Liveness step timed out.',
              errorMessage: 'We could not confirm that step in time.',
              incrementRedo: true,
              incrementTimeout: true,
            );
        HapticFeedback.lightImpact();
        unawaited(_stopImageStream());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(selfieCaptureUiProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _cameraLifecycle.markRouteActive(false);
          unawaited(_pauseCamera());
        }
      },
      child: Scaffold(
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
              _ChallengeStatusBanner(uiState: uiState),
              if (uiState.hasError) ...[
                const SizedBox(height: AppSpacing.s8),
                _ErrorBanner(message: uiState.errorMessage ?? ''),
              ],
              const SizedBox(height: AppSpacing.s16),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: FutureBuilder<void>(
                      future: _initializeFuture,
                      builder: (context, snapshot) {
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

                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
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

                        return _SelfieCameraStage(
                          controller: _controller!,
                          isFaceDetected: uiState.isFaceDetected,
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
                      : (uiState.isPermissionDenied ||
                              uiState.cameraErrorMessage != null)
                          ? 'Retry camera'
                          : uiState.shouldRedo
                              ? 'Redo liveness check'
                              : 'Restart liveness check',
                  enabled: !uiState.isAutoCapturing,
                  onTap: uiState.isPermissionDenied ||
                          uiState.cameraErrorMessage != null
                      ? _retryCameraSetup
                      : () {
                          ref
                              .read(selfieCaptureUiProvider.notifier)
                              .resetFlow();
                          _blinkPrimed = false;
                          _scheduleChallengeTimeout();
                          _cameraLifecycle.markRouteActive(true);
                          unawaited(_startImageStream());
                          HapticFeedback.selectionClick();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryCameraSetup() async {
    _cameraLifecycle.markRouteActive(true);
    _blinkPrimed = false;
    _capturingSelfie = false;
    _challengeTimeoutTimer?.cancel();
    await _disposeController();
    if (!mounted) return;
    setState(() {
      _initializeFuture = _ensureCameraInitialized();
    });
  }

  Map<String, dynamic> _selfieConfigToJson(SelfieLivenessConfig config) {
    return {
      'resolution_preset': config.resolutionPreset.name,
      'android_image_format_group': config.androidImageFormatGroup.name,
      'ios_image_format_group': config.iosImageFormatGroup.name,
      'frame_stride': config.frameStride,
      'challenge_timeout_ms': config.challengeTimeout.inMilliseconds,
      'blink_closed_threshold': config.blinkClosedThreshold,
      'blink_open_threshold': config.blinkOpenThreshold,
      'head_turn_threshold': config.headTurnThreshold,
      'look_straight_threshold': config.lookStraightThreshold,
      'mobile_shadow': {
        'enabled': config.mobileShadow.enabled,
        'fail_open': config.mobileShadow.failOpen,
      },
    };
  }

  void _onCameraImage(CameraImage cameraImage) {
    if (!mounted || _capturingSelfie) return;
    _frameCounter++;
    if (_frameCounter % widget.effectiveLivenessConfig.frameStride != 0) {
      return;
    }
    if (_isProcessingFrame) return;

    _isProcessingFrame = true;
    unawaited(_processCameraFrame(cameraImage));
  }
}

class _ChallengeStatusBanner extends StatelessWidget {
  const _ChallengeStatusBanner({required this.uiState});

  final SelfieCaptureUiState uiState;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (uiState.challengeTone) {
      SelfieChallengeTone.success => (
          colors.primaryContainer,
          colors.onPrimaryContainer,
          Icons.check_circle,
        ),
      SelfieChallengeTone.error => (
          colors.errorContainer,
          colors.onErrorContainer,
          Icons.error,
        ),
      SelfieChallengeTone.neutral => (
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant,
          Icons.info,
        ),
    };

    return Container(
      width: double.infinity,
      padding: AppSpacing.padH16V12,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uiState.statusMessage,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (uiState.helperMessage != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    uiState.helperMessage!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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

class _SelfieCameraStage extends StatelessWidget {
  const _SelfieCameraStage({
    required this.controller,
    required this.isFaceDetected,
  });

  final CameraController controller;
  final bool isFaceDetected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.s10),
      child: AspectRatio(
        aspectRatio: 0.72,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black),
              _SelfiePreview(controller: controller),
              const _FaceOvalOverlay(),
              Positioned(
                top: AppSpacing.s16,
                left: AppSpacing.s16,
                right: AppSpacing.s16,
                child: _DetectionBadge(
                  isFaceDetected: isFaceDetected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelfiePreview extends StatelessWidget {
  const _SelfiePreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        final previewAspectRatio = previewSize == null
            ? (1 / controller.value.aspectRatio)
            : (previewSize.height / previewSize.width);

        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: constraints.maxHeight * previewAspectRatio,
              height: constraints.maxHeight,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
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
          isFaceDetected ? 'Face aligned' : 'Position your face in the oval',
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ovalWidth = constraints.maxWidth * 0.62;
          final ovalHeight = constraints.maxHeight * 0.58;
          return Center(
            child: Container(
              width: ovalWidth.clamp(210.0, 290.0),
              height: ovalHeight.clamp(280.0, 380.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.92),
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
          );
        },
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
                  ? 'Enable camera access in your phone settings to continue the selfie check.'
                  : 'Allow camera access to continue the selfie and liveness check.',
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
