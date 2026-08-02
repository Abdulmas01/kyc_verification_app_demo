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

  void setCameraReady(bool value) {
    state = state.copyWith(
      isCameraReady: value,
      cameraErrorMessage: value ? null : state.cameraErrorMessage,
      challengeTone: SelfieChallengeTone.neutral,
    );
  }

  void setPermissionDenied({required bool permanentlyDenied}) {
    state = state.copyWith(
      isPermissionDenied: true,
      isPermanentlyDenied: permanentlyDenied,
      isCameraReady: false,
      isDetecting: false,
      isAutoCapturing: false,
      cameraErrorMessage: permanentlyDenied
          ? 'Camera access is permanently denied. Enable it in settings.'
          : 'Camera access is required for selfie capture.',
      errorMessage: null,
      statusMessage: 'Allow camera access to continue.',
      helperMessage: null,
      challengeTone: SelfieChallengeTone.error,
    );
  }

  void clearPermissionError() {
    if (!state.isPermissionDenied &&
        !state.isPermanentlyDenied &&
        state.cameraErrorMessage == null) {
      return;
    }
    state = state.copyWith(
      isPermissionDenied: false,
      isPermanentlyDenied: false,
      cameraErrorMessage: null,
      challengeTone: SelfieChallengeTone.neutral,
    );
  }

  void setCameraError(String message) {
    state = state.copyWith(
      isCameraReady: false,
      isDetecting: false,
      isAutoCapturing: false,
      cameraErrorMessage: message,
      errorMessage: null,
      statusMessage: 'Camera unavailable.',
      helperMessage: null,
      challengeTone: SelfieChallengeTone.error,
    );
  }

  void setChallengeMessage(String message, {String? helperMessage}) {
    state = state.copyWith(
      statusMessage: message,
      helperMessage: helperMessage,
      errorMessage: null,
      challengeTone: SelfieChallengeTone.neutral,
      shouldRedo: false,
    );
  }

  void markBlinkComplete() {
    state = state.copyWith(
      completedChallenges: 1,
      currentChallenge: SelfieLivenessChallenge.turnLeft,
      statusMessage: 'Blink captured.',
      helperMessage: 'Now slowly turn your head to the left.',
      errorMessage: null,
      challengeTone: SelfieChallengeTone.success,
      shouldRedo: false,
    );
  }

  void markTurnLeftComplete() {
    state = state.copyWith(
      completedChallenges: 2,
      currentChallenge: SelfieLivenessChallenge.turnRight,
      statusMessage: 'Left turn captured.',
      helperMessage: 'Now slowly turn your head to the right.',
      errorMessage: null,
      challengeTone: SelfieChallengeTone.success,
      shouldRedo: false,
    );
  }

  void markTurnRightComplete() {
    state = state.copyWith(
      completedChallenges: 3,
      currentChallenge: SelfieLivenessChallenge.lookStraight,
      statusMessage: 'Right turn captured.',
      helperMessage: 'Look straight at the camera and hold still.',
      errorMessage: null,
      challengeTone: SelfieChallengeTone.success,
      shouldRedo: false,
    );
  }

  void startAutoCapture() {
    state = state.copyWith(
      isAutoCapturing: true,
      isDetecting: true,
      statusMessage: 'Hold steady. Capturing your best selfie...',
      helperMessage: 'Almost done.',
      errorMessage: null,
      challengeTone: SelfieChallengeTone.success,
    );
  }

  void startCapture() {
    state = state.copyWith(
      isDetecting: true,
      isAutoCapturing: true,
      statusMessage: 'Capturing your selfie...',
      helperMessage: 'Please hold still.',
      errorMessage: null,
      challengeTone: SelfieChallengeTone.success,
    );
  }

  void setError({
    required String statusMessage,
    required String errorMessage,
    String? helperMessage,
    bool shouldRedo = false,
  }) {
    state = state.copyWith(
      isDetecting: false,
      isAutoCapturing: false,
      statusMessage: statusMessage,
      helperMessage: helperMessage,
      errorMessage: errorMessage,
      challengeTone: SelfieChallengeTone.error,
      failedAttempts: state.failedAttempts + 1,
      shouldRedo: shouldRedo,
    );
  }

  void completeFlow() {
    state = state.copyWith(
      isDetecting: false,
      isAutoCapturing: false,
      currentChallenge: SelfieLivenessChallenge.complete,
      statusMessage: 'Liveness check complete.',
      helperMessage: 'Your selfie was captured successfully.',
      errorMessage: null,
      challengeTone: SelfieChallengeTone.success,
      shouldRedo: false,
    );
  }

  void requestRedo({
    required String statusMessage,
    required String errorMessage,
    String? helperMessage,
  }) {
    state = state.copyWith(
      isDetecting: false,
      isAutoCapturing: false,
      statusMessage: statusMessage,
      helperMessage: helperMessage,
      errorMessage: errorMessage,
      challengeTone: SelfieChallengeTone.error,
      failedAttempts: state.failedAttempts + 1,
      shouldRedo: true,
    );
  }

  void resetFlow() {
    state = state.copyWith(
      isDetecting: false,
      isFaceDetected: false,
      isAutoCapturing: false,
      isPermissionDenied: false,
      isPermanentlyDenied: false,
      completedChallenges: 0,
      currentChallenge: SelfieLivenessChallenge.blink,
      statusMessage: 'Blink naturally to begin the liveness check.',
      helperMessage: 'We will guide you through three quick checks.',
      cameraErrorMessage: null,
      errorMessage: null,
      challengeTone: SelfieChallengeTone.neutral,
      shouldRedo: false,
    );
  }
}

final selfieCaptureUiProvider =
    AutoDisposeNotifierProvider<SelfieCaptureUiNotifier, SelfieCaptureUiState>(
  SelfieCaptureUiNotifier.new,
);
