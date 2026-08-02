class ProcessingUiState {
  final int attempts;
  final int maxAttempts;
  final bool hasNavigated;

  const ProcessingUiState({
    required this.attempts,
    required this.maxAttempts,
    required this.hasNavigated,
  });

  factory ProcessingUiState.initial({int maxAttempts = 3}) {
    return ProcessingUiState(
      attempts: 0,
      maxAttempts: maxAttempts,
      hasNavigated: false,
    );
  }

  ProcessingUiState copyWith({
    int? attempts,
    int? maxAttempts,
    bool? hasNavigated,
  }) {
    return ProcessingUiState(
      attempts: attempts ?? this.attempts,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      hasNavigated: hasNavigated ?? this.hasNavigated,
    );
  }

  bool get canRetry => attempts < maxAttempts;
}
