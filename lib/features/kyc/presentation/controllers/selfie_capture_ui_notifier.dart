import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/selfie_capture_ui_state.dart';

class SelfieCaptureUiNotifier
    extends AutoDisposeNotifier<SelfieCaptureUiState> {
  @override
  SelfieCaptureUiState build() => SelfieCaptureUiState.initial();

  void startDetection() {
    state = state.copyWith(
      isDetecting: true,
      statusMessage: 'Checking for a face...',
      errorMessage: null,
    );
  }

  void setError({
    required String statusMessage,
    required String errorMessage,
  }) {
    state = state.copyWith(
      isDetecting: false,
      statusMessage: statusMessage,
      errorMessage: errorMessage,
    );
  }

  void resetIdleMessage(
      [String message = 'Align your face inside the frame.']) {
    state = state.copyWith(
      isDetecting: false,
      statusMessage: message,
      errorMessage: null,
    );
  }

  void clearError() {
    if (!state.hasError) return;
    state = state.copyWith(errorMessage: null);
  }
}

final selfieCaptureUiProvider =
    AutoDisposeNotifierProvider<SelfieCaptureUiNotifier, SelfieCaptureUiState>(
  SelfieCaptureUiNotifier.new,
);
