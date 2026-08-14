class SelfieCaptureRuntimeController {
  bool _isProcessingFrame = false;
  bool _blinkPrimed = false;
  bool _capturingSelfie = false;
  int _frameCounter = 0;
  int _analysisFailureCount = 0;
  String? _lastFailureFeedbackKey;

  bool get isProcessingFrame => _isProcessingFrame;
  bool get isBlinkPrimed => _blinkPrimed;
  bool get isCapturingSelfie => _capturingSelfie;
  int get frameCounter => _frameCounter;
  int get analysisFailureCount => _analysisFailureCount;

  void resetFlow() {
    _isProcessingFrame = false;
    _blinkPrimed = false;
    _capturingSelfie = false;
    _analysisFailureCount = 0;
    _lastFailureFeedbackKey = null;
  }

  void resetProcessing() {
    _isProcessingFrame = false;
  }

  void setCapturingSelfie(bool value) {
    _capturingSelfie = value;
  }

  void setBlinkPrimed(bool value) {
    _blinkPrimed = value;
  }

  bool shouldProcessNextFrame(int frameStride) {
    _frameCounter++;
    if (_capturingSelfie || _isProcessingFrame) {
      return false;
    }
    if (_frameCounter % frameStride != 0) {
      return false;
    }
    _isProcessingFrame = true;
    return true;
  }

  int registerAnalysisFailure() {
    _analysisFailureCount++;
    return _analysisFailureCount;
  }

  void resetAnalysisFailures() {
    _analysisFailureCount = 0;
  }

  bool shouldEmitFailureFeedback(String key) {
    if (_lastFailureFeedbackKey == key) {
      return false;
    }
    _lastFailureFeedbackKey = key;
    return true;
  }

  void clearFailureFeedback() {
    _lastFailureFeedbackKey = null;
  }
}
