class SelfieCaptureUiState {
  static const Object _sentinel = Object();

  final String statusMessage;
  final bool isDetecting;
  final String? errorMessage;

  const SelfieCaptureUiState({
    required this.statusMessage,
    required this.isDetecting,
    this.errorMessage,
  });

  factory SelfieCaptureUiState.initial() {
    return const SelfieCaptureUiState(
      statusMessage: 'Align your face inside the frame.',
      isDetecting: false,
      errorMessage: null,
    );
  }

  SelfieCaptureUiState copyWith({
    String? statusMessage,
    bool? isDetecting,
    Object? errorMessage = _sentinel,
  }) {
    return SelfieCaptureUiState(
      statusMessage: statusMessage ?? this.statusMessage,
      isDetecting: isDetecting ?? this.isDetecting,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}
