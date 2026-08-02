import 'package:camera/camera.dart';

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
        performanceLogEvery = 30;

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
        performanceLogEvery = 40;

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
        performanceLogEvery = 20;
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
        lookStraightThreshold = 8;

  const SelfieLivenessConfig.fast()
      : resolutionPreset = ResolutionPreset.medium,
        androidImageFormatGroup = ImageFormatGroup.yuv420,
        iosImageFormatGroup = ImageFormatGroup.bgra8888,
        frameStride = 5,
        challengeTimeout = const Duration(seconds: 10),
        blinkClosedThreshold = 0.22,
        blinkOpenThreshold = 0.68,
        headTurnThreshold = 16,
        lookStraightThreshold = 10;

  const SelfieLivenessConfig.highQuality()
      : resolutionPreset = ResolutionPreset.veryHigh,
        androidImageFormatGroup = ImageFormatGroup.yuv420,
        iosImageFormatGroup = ImageFormatGroup.bgra8888,
        frameStride = 3,
        challengeTimeout = const Duration(seconds: 14),
        blinkClosedThreshold = 0.25,
        blinkOpenThreshold = 0.72,
        headTurnThreshold = 20,
        lookStraightThreshold = 7;
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
