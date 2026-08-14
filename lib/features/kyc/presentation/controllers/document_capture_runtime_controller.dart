import '../models/kyc_capture_config.dart';

class DocumentCaptureRuntimeController {
  DocumentCaptureRuntimeController({
    required int initialFrameStride,
  }) : _frameStride = initialFrameStride;

  final Stopwatch _sessionStopwatch = Stopwatch();
  bool _isProcessingFrame = false;
  int _frameCounter = 0;
  int _frameStride;
  int _strideAdjustCounter = 0;
  double _avgInferenceMs = 0;
  int _inferenceSamples = 0;
  bool _pendingDebugSampleExport = false;
  bool _isNavigatingToSelfie = false;
  Duration _lastGuidanceTransitionAt = Duration.zero;

  bool get isProcessingFrame => _isProcessingFrame;
  int get frameCounter => _frameCounter;
  int get frameStride => _frameStride;
  double get avgInferenceMs => _avgInferenceMs;
  int get inferenceSamples => _inferenceSamples;
  bool get pendingDebugSampleExport => _pendingDebugSampleExport;
  bool get isNavigatingToSelfie => _isNavigatingToSelfie;
  Duration get lastGuidanceTransitionAt => _lastGuidanceTransitionAt;
  Duration get sessionElapsed => _sessionStopwatch.elapsed;

  void startSession() {
    if (!_sessionStopwatch.isRunning) {
      _sessionStopwatch.start();
    }
  }

  void setPendingDebugSampleExport(bool value) {
    _pendingDebugSampleExport = value;
  }

  void setNavigatingToSelfie(bool value) {
    _isNavigatingToSelfie = value;
  }

  void markTransitionLogged(Duration at) {
    _lastGuidanceTransitionAt = at;
  }

  bool shouldProcessNextFrame() {
    _frameCounter++;
    if (_isProcessingFrame) {
      return false;
    }
    if (_frameCounter % _frameStride != 0) {
      return false;
    }
    _isProcessingFrame = true;
    return true;
  }

  void finishFrameProcessing() {
    _isProcessingFrame = false;
  }

  void resetTransientState({
    required int initialFrameStride,
  }) {
    _isProcessingFrame = false;
    _frameStride = initialFrameStride;
    _strideAdjustCounter = 0;
    _avgInferenceMs = 0;
    _inferenceSamples = 0;
    _lastGuidanceTransitionAt = Duration.zero;
  }

  void recordInference({
    required double ms,
    required DocumentCaptureConfig config,
  }) {
    _inferenceSamples++;
    _avgInferenceMs =
        ((_avgInferenceMs * (_inferenceSamples - 1)) + ms) / _inferenceSamples;

    _strideAdjustCounter++;
    if (_strideAdjustCounter < config.strideAdjustmentWindow) {
      return;
    }

    if (_avgInferenceMs > config.increaseStrideInferenceMs &&
        _frameStride < config.maxFrameStride) {
      _frameStride++;
    } else if (_avgInferenceMs < config.decreaseStrideInferenceMs &&
        _frameStride > config.minFrameStride) {
      _frameStride--;
    }
    _strideAdjustCounter = 0;
  }

  String formatDuration(Duration duration) {
    final totalMs = duration.inMilliseconds;
    final seconds = totalMs ~/ 1000;
    final millis = totalMs % 1000;
    return '$seconds.${(millis ~/ 10).toString().padLeft(2, '0')}s';
  }
}
