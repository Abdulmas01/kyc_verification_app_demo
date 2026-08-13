import 'package:camera/camera.dart';

enum DocumentQualityMode { guidanceOnly, qualityGate }

class DocumentCaptureConfig {
  final ResolutionPreset resolutionPreset;
  final ImageFormatGroup imageFormatGroup;
  final int initialFrameStride;
  final int minFrameStride;
  final int maxFrameStride;
  final int strideAdjustmentWindow;
  final double increaseStrideInferenceMs;
  final double decreaseStrideInferenceMs;
  final Duration autoCaptureHoldDuration;
  final int performanceLogEvery;
  final int guidanceStabilityFrames;
  final DocumentQualityMode qualityMode;

  const DocumentCaptureConfig({
    required this.resolutionPreset,
    required this.imageFormatGroup,
    required this.initialFrameStride,
    required this.minFrameStride,
    required this.maxFrameStride,
    required this.strideAdjustmentWindow,
    required this.increaseStrideInferenceMs,
    required this.decreaseStrideInferenceMs,
    required this.autoCaptureHoldDuration,
    required this.performanceLogEvery,
    required this.guidanceStabilityFrames,
    required this.qualityMode,
  });

  const DocumentCaptureConfig.balanced()
      : resolutionPreset = ResolutionPreset.medium,
        imageFormatGroup = ImageFormatGroup.yuv420,
        initialFrameStride = 5,
        minFrameStride = 3,
        maxFrameStride = 8,
        strideAdjustmentWindow = 10,
        increaseStrideInferenceMs = 80,
        decreaseStrideInferenceMs = 40,
        autoCaptureHoldDuration = const Duration(milliseconds: 1500),
        performanceLogEvery = 30,
        guidanceStabilityFrames = 3,
        qualityMode = DocumentQualityMode.guidanceOnly;

  const DocumentCaptureConfig.fast()
      : resolutionPreset = ResolutionPreset.low,
        imageFormatGroup = ImageFormatGroup.yuv420,
        initialFrameStride = 6,
        minFrameStride = 4,
        maxFrameStride = 9,
        strideAdjustmentWindow = 8,
        increaseStrideInferenceMs = 65,
        decreaseStrideInferenceMs = 30,
        autoCaptureHoldDuration = const Duration(milliseconds: 1200),
        performanceLogEvery = 40,
        guidanceStabilityFrames = 2,
        qualityMode = DocumentQualityMode.guidanceOnly;

  const DocumentCaptureConfig.highQuality()
      : resolutionPreset = ResolutionPreset.high,
        imageFormatGroup = ImageFormatGroup.yuv420,
        initialFrameStride = 4,
        minFrameStride = 2,
        maxFrameStride = 6,
        strideAdjustmentWindow = 12,
        increaseStrideInferenceMs = 95,
        decreaseStrideInferenceMs = 45,
        autoCaptureHoldDuration = const Duration(milliseconds: 1700),
        performanceLogEvery = 20,
        guidanceStabilityFrames = 4,
        qualityMode = DocumentQualityMode.guidanceOnly;
}

class SelfieLivenessConfig {
  final ResolutionPreset resolutionPreset;
  final ImageFormatGroup androidImageFormatGroup;
  final ImageFormatGroup iosImageFormatGroup;
  final int frameStride;
  final Duration challengeTimeout;
  final double blinkClosedThreshold;
  final double blinkOpenThreshold;
  final double headTurnThreshold;
  final double lookStraightThreshold;
  final MobileLivenessShadowConfig mobileShadow;

  /// Active liveness guidance plus optional mobile shadow benchmarking config.
  ///
  /// `mobileShadow` never changes the authoritative decision path. It exists so
  /// we can test whether a compressed liveness model loads and runs on device,
  /// then compare those shadow outputs with backend scores for thesis evidence.
  const SelfieLivenessConfig({
    required this.resolutionPreset,
    required this.androidImageFormatGroup,
    required this.iosImageFormatGroup,
    required this.frameStride,
    required this.challengeTimeout,
    required this.blinkClosedThreshold,
    required this.blinkOpenThreshold,
    required this.headTurnThreshold,
    required this.lookStraightThreshold,
    this.mobileShadow = const MobileLivenessShadowConfig.disabled(),
  });

  const SelfieLivenessConfig.balanced()
      : resolutionPreset = ResolutionPreset.high,
        androidImageFormatGroup = ImageFormatGroup.yuv420,
        iosImageFormatGroup = ImageFormatGroup.bgra8888,
        frameStride = 4,
        challengeTimeout = const Duration(seconds: 12),
        blinkClosedThreshold = 0.25,
        blinkOpenThreshold = 0.7,
        headTurnThreshold = 18,
        lookStraightThreshold = 8,
        mobileShadow = const MobileLivenessShadowConfig.disabled();

  const SelfieLivenessConfig.fast()
      : resolutionPreset = ResolutionPreset.medium,
        androidImageFormatGroup = ImageFormatGroup.yuv420,
        iosImageFormatGroup = ImageFormatGroup.bgra8888,
        frameStride = 5,
        challengeTimeout = const Duration(seconds: 10),
        blinkClosedThreshold = 0.22,
        blinkOpenThreshold = 0.68,
        headTurnThreshold = 16,
        lookStraightThreshold = 10,
        mobileShadow = const MobileLivenessShadowConfig.disabled();

  const SelfieLivenessConfig.highQuality()
      : resolutionPreset = ResolutionPreset.veryHigh,
        androidImageFormatGroup = ImageFormatGroup.yuv420,
        iosImageFormatGroup = ImageFormatGroup.bgra8888,
        frameStride = 3,
        challengeTimeout = const Duration(seconds: 14),
        blinkClosedThreshold = 0.25,
        blinkOpenThreshold = 0.72,
        headTurnThreshold = 20,
        lookStraightThreshold = 7,
        mobileShadow = const MobileLivenessShadowConfig.disabled();
}

class MobileLivenessShadowConfig {
  /// Enables optional mobile liveness inference for benchmarking and comparison.
  ///
  /// Default this to `false`. If the model is unready, missing, or unstable on a
  /// device, the thesis flow should continue with backend liveness only.
  final bool enabled;

  /// When `true`, shadow-model failures are logged instead of blocking capture.
  final bool failOpen;

  const MobileLivenessShadowConfig({
    required this.enabled,
    required this.failOpen,
  });

  const MobileLivenessShadowConfig.disabled()
      : enabled = false,
        failOpen = true;

  const MobileLivenessShadowConfig.enabledShadow()
      : enabled = true,
        failOpen = true;
}

class KycCaptureProfile {
  final DocumentCaptureConfig documentCapture;
  final SelfieLivenessConfig selfieLiveness;

  const KycCaptureProfile({
    required this.documentCapture,
    required this.selfieLiveness,
  });

  const KycCaptureProfile.balanced()
      : documentCapture = const DocumentCaptureConfig.balanced(),
        selfieLiveness = const SelfieLivenessConfig.balanced();

  const KycCaptureProfile.fast()
      : documentCapture = const DocumentCaptureConfig.fast(),
        selfieLiveness = const SelfieLivenessConfig.fast();

  const KycCaptureProfile.highQuality()
      : documentCapture = const DocumentCaptureConfig.highQuality(),
        selfieLiveness = const SelfieLivenessConfig.highQuality();
}
