class DocumentCaptureUiState {
  static const Object _sentinel = Object();

  final String statusMessage;
  final bool isDetecting;
  final bool documentDetected;
  final bool isQualityGood;
  final double qualityConfidence;
  final bool isAutoCapturing;
  final bool isPermissionDenied;
  final bool isPermanentlyDenied;
  final bool isCameraReady;
  final String? capturedPreviewPath;
  final String? cameraErrorMessage;
  final String? errorMessage;

  const DocumentCaptureUiState({
    required this.statusMessage,
    required this.isDetecting,
    required this.documentDetected,
    required this.isQualityGood,
    required this.qualityConfidence,
    required this.isAutoCapturing,
    required this.isPermissionDenied,
    required this.isPermanentlyDenied,
    required this.isCameraReady,
    this.capturedPreviewPath,
    this.cameraErrorMessage,
    this.errorMessage,
  });

  factory DocumentCaptureUiState.initial() {
    return const DocumentCaptureUiState(
      statusMessage: 'Align your ID inside the frame.',
      isDetecting: false,
      documentDetected: false,
      isQualityGood: false,
      qualityConfidence: 0,
      isAutoCapturing: false,
      isPermissionDenied: false,
      isPermanentlyDenied: false,
      isCameraReady: false,
      capturedPreviewPath: null,
      cameraErrorMessage: null,
      errorMessage: null,
    );
  }

  DocumentCaptureUiState copyWith({
    String? statusMessage,
    bool? isDetecting,
    bool? documentDetected,
    bool? isQualityGood,
    double? qualityConfidence,
    bool? isAutoCapturing,
    bool? isPermissionDenied,
    bool? isPermanentlyDenied,
    bool? isCameraReady,
    Object? capturedPreviewPath = _sentinel,
    Object? cameraErrorMessage = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return DocumentCaptureUiState(
      statusMessage: statusMessage ?? this.statusMessage,
      isDetecting: isDetecting ?? this.isDetecting,
      documentDetected: documentDetected ?? this.documentDetected,
      isQualityGood: isQualityGood ?? this.isQualityGood,
      qualityConfidence: qualityConfidence ?? this.qualityConfidence,
      isAutoCapturing: isAutoCapturing ?? this.isAutoCapturing,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      isPermanentlyDenied: isPermanentlyDenied ?? this.isPermanentlyDenied,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      capturedPreviewPath: capturedPreviewPath == _sentinel
          ? this.capturedPreviewPath
          : capturedPreviewPath as String?,
      cameraErrorMessage: cameraErrorMessage == _sentinel
          ? this.cameraErrorMessage
          : cameraErrorMessage as String?,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}
