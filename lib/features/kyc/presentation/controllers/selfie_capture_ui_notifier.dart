import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/selfie_capture_ui_state.dart';

class SelfieCaptureUiNotifier
    extends AutoDisposeNotifier<SelfieCaptureUiState> {
  @override
  SelfieCaptureUiState build() => SelfieCaptureUiState.initial();

  void setFaceDetected(bool value) {
    if (state.isFaceDetected == value) return;
    state = state.copyWith(isFaceDetected: value);
  }

  void setChallengeMessage(String message) {
    state = state.copyWith(
      statusMessage: message,
      errorMessage: null,
    );
  }

  void markBlinkComplete() {
    state = state.copyWith(
      completedChallenges: 1,
      currentChallenge: SelfieLivenessChallenge.turnLeft,
      statusMessage: 'Great. Now slowly turn your head to the left.',
      errorMessage: null,
    );
  }

  void markTurnLeftComplete() {
    state = state.copyWith(
      completedChallenges: 2,
      currentChallenge: SelfieLivenessChallenge.turnRight,
      statusMessage: 'Nice. Now slowly turn your head to the right.',
      errorMessage: null,
    );
  }

  void markTurnRightComplete() {
    state = state.copyWith(
      completedChallenges: 3,
      currentChallenge: SelfieLivenessChallenge.lookStraight,
      statusMessage: 'Perfect. Look straight and hold still.',
      errorMessage: null,
    );
  }

  void startAutoCapture() {
    state = state.copyWith(
      isAutoCapturing: true,
      isDetecting: true,
      statusMessage: 'Hold steady. Capturing your best selfie...',
      errorMessage: null,
    );
  }

  void startCapture() {
    state = state.copyWith(
      isDetecting: true,
      isAutoCapturing: true,
      statusMessage: 'Capturing your selfie...',
      errorMessage: null,
    );
  }

  void setError({
    required String statusMessage,
    required String errorMessage,
  }) {
    state = state.copyWith(
      isDetecting: false,
      isAutoCapturing: false,
      statusMessage: statusMessage,
      errorMessage: errorMessage,
    );
  }

  void completeFlow() {
    state = state.copyWith(
      isDetecting: false,
      isAutoCapturing: false,
      currentChallenge: SelfieLivenessChallenge.complete,
      statusMessage: 'Liveness check complete.',
      errorMessage: null,
    );
  }

  void resetFlow() {
    state = state.copyWith(
      isDetecting: false,
      isFaceDetected: false,
      isAutoCapturing: false,
      completedChallenges: 0,
      currentChallenge: SelfieLivenessChallenge.blink,
      statusMessage: 'Blink naturally to begin the liveness check.',
      errorMessage: null,
    );
  }
}

final selfieCaptureUiProvider =
    AutoDisposeNotifierProvider<SelfieCaptureUiNotifier, SelfieCaptureUiState>(
  SelfieCaptureUiNotifier.new,
);
