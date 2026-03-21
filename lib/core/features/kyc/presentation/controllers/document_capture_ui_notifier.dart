import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document_capture_ui_state.dart';

class DocumentCaptureUiNotifier
    extends AutoDisposeNotifier<DocumentCaptureUiState> {
  @override
  DocumentCaptureUiState build() => DocumentCaptureUiState.initial();

  void setStatus(String message) {
    state = state.copyWith(statusMessage: message);
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
    );
  }
}

final documentCaptureUiProvider = AutoDisposeNotifierProvider<
    DocumentCaptureUiNotifier, DocumentCaptureUiState>(
  DocumentCaptureUiNotifier.new,
);
