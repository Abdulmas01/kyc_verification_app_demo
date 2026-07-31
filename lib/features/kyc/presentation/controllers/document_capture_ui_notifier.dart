import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document_capture_ui_state.dart';

class DocumentCaptureUiNotifier
    extends AutoDisposeNotifier<DocumentCaptureUiState> {
  @override
  DocumentCaptureUiState build() => DocumentCaptureUiState.initial();

  void setStatus(String message) {
    state = state.copyWith(statusMessage: message);
  }

  void setCameraReady(bool value) {
    state = state.copyWith(
      isCameraReady: value,
      cameraErrorMessage: value ? null : state.cameraErrorMessage,
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
          : 'Camera access is required for document capture.',
      statusMessage: 'Allow camera access to continue.',
      errorMessage: null,
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
    );
  }

  void setCameraError(String message) {
    state = state.copyWith(
      isCameraReady: false,
      isDetecting: false,
      isAutoCapturing: false,
      cameraErrorMessage: message,
      statusMessage: 'Camera unavailable.',
      errorMessage: null,
    );
  }

  void setError(String message) {
    state = state.copyWith(
      statusMessage: message,
      errorMessage: message,
    );
  }

  void clearError() {
    if (!state.hasError) return;
    state = state.copyWith(errorMessage: null);
  }

  void setDetecting(bool value) {
    state = state.copyWith(isDetecting: value);
  }

  void setDocumentDetected(bool value) {
    state = state.copyWith(documentDetected: value);
  }

  void setAutoCapturing(bool value) {
    state = state.copyWith(isAutoCapturing: value);
  }

  void updateQuality({
    required String message,
    required double confidence,
    required bool isGood,
  }) {
    state = state.copyWith(
      statusMessage: message,
      qualityConfidence: confidence,
      isQualityGood: isGood,
      errorMessage: null,
    );
  }

  void resetFlow() {
    state = DocumentCaptureUiState.initial();
  }
}

final documentCaptureUiProvider = AutoDisposeNotifierProvider<
    DocumentCaptureUiNotifier, DocumentCaptureUiState>(
  DocumentCaptureUiNotifier.new,
);
