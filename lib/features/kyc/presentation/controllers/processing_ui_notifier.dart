import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/processing_ui_state.dart';

class ProcessingUiNotifier extends AutoDisposeNotifier<ProcessingUiState> {
  static const int defaultMaxAttempts = 3;

  @override
  ProcessingUiState build() {
    return ProcessingUiState.initial(maxAttempts: defaultMaxAttempts);
  }

  bool registerAttempt() {
    if (!state.canRetry) return false;
    state = state.copyWith(
      attempts: state.attempts + 1,
      hasNavigated: false,
    );
    return true;
  }

  void markNavigated() {
    if (state.hasNavigated) return;
    state = state.copyWith(hasNavigated: true);
  }

  void reset() {
    state = ProcessingUiState.initial(maxAttempts: state.maxAttempts);
  }
}

final processingUiProvider =
    AutoDisposeNotifierProvider<ProcessingUiNotifier, ProcessingUiState>(
  ProcessingUiNotifier.new,
);
