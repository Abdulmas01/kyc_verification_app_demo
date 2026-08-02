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
}
