class DocumentCaptureUiState {
  final String statusMessage;
  final bool isDetecting;
  final bool documentDetected;
  final bool isQualityGood;
  final double qualityConfidence;
  final bool isAutoCapturing;

  const DocumentCaptureUiState({
    required this.statusMessage,
    required this.isDetecting,
    required this.documentDetected,
    required this.isQualityGood,
    required this.qualityConfidence,
    required this.isAutoCapturing,
  });

  factory DocumentCaptureUiState.initial() {
    return const DocumentCaptureUiState(
      statusMessage: 'Align your ID inside the frame.',
      isDetecting: false,
      documentDetected: false,
      isQualityGood: false,
      qualityConfidence: 0,
      isAutoCapturing: false,
    );
  }

  DocumentCaptureUiState copyWith({
    String? statusMessage,
    bool? isDetecting,
    bool? documentDetected,
    bool? isQualityGood,
    double? qualityConfidence,
    bool? isAutoCapturing,
  }) {
    return DocumentCaptureUiState(
      statusMessage: statusMessage ?? this.statusMessage,
      isDetecting: isDetecting ?? this.isDetecting,
      documentDetected: documentDetected ?? this.documentDetected,
      isQualityGood: isQualityGood ?? this.isQualityGood,
      qualityConfidence: qualityConfidence ?? this.qualityConfidence,
      isAutoCapturing: isAutoCapturing ?? this.isAutoCapturing,
    );
  }
}
