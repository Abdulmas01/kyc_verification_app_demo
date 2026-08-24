import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/features/kyc/domain/models/face_embedding_match_result.dart';
import 'package:kyc_verification_app_demo/features/kyc/domain/models/verification_result.dart';
import 'package:kyc_verification_app_demo/features/kyc/data/services/document_quality_debug_exporter.dart';
import 'package:kyc_verification_app_demo/features/kyc/presentation/models/thesis_debug_report.dart';

class ThesisDebugReportNotifier extends Notifier<ThesisDebugReport> {
  @override
  ThesisDebugReport build() => ThesisDebugReport.initial();

  void startRun({
    required Map<String, dynamic> documentConfig,
  }) {
    state = ThesisDebugReport(
      runId: 'kyc_${DateTime.now().millisecondsSinceEpoch}',
      startedAt: DateTime.now(),
      documentConfig: documentConfig,
    );
  }

  void attachSelfieConfig(Map<String, dynamic> selfieConfig) {
    state = state.copyWith(selfieConfig: selfieConfig);
  }

  void configureMobileLivenessShadow({required bool enabled}) {
    state = state.copyWith(
      mobileLivenessShadow: state.mobileLivenessShadow.copyWith(
        enabled: enabled,
        attempted: false,
        available: false,
        clearScore: true,
        clearThreshold: true,
        clearLatencyMs: true,
        clearError: true,
      ),
    );
  }

  void recordDocumentQuality({
    required String statusMessage,
    required String qualityLabel,
    required double confidence,
    required bool accepted,
    required double averageInferenceMs,
    required int inferenceSamples,
    required int frameStride,
  }) {
    state = state.copyWith(
      documentStatusMessage: statusMessage,
      documentQualityLabel: qualityLabel,
      documentQualityConfidence: confidence,
      documentQualityAccepted: accepted,
      documentAverageInferenceMs: averageInferenceMs,
      documentInferenceSamples: inferenceSamples,
      documentFrameStride: frameStride,
      clearDocumentError: true,
    );
  }

  void markDocumentAutoCaptureTriggered() {
    state = state.copyWith(documentAutoCaptureTriggered: true);
  }

  void recordDocumentFailure(String message) {
    state = state.copyWith(documentError: message);
  }

  void recordDocumentCapture({
    required bool detected,
    required String documentPath,
    String? normalizedPath,
    String? statusMessage,
  }) {
    state = state.copyWith(
      documentDetected: detected,
      documentPath: documentPath,
      normalizedDocumentPath: normalizedPath,
      documentStatusMessage: statusMessage,
      clearDocumentError: true,
    );
  }

  void recordDocumentQualityDebugSample(
      DocumentQualityDebugExportResult result) {
    state = state.copyWith(
      documentQualityDebugSample: state.documentQualityDebugSample.copyWith(
        directoryPath: result.directoryPath,
        fullFramePath: result.fullFramePath,
        modelInputPath: result.modelInputPath,
        metadataPath: result.metadataPath,
      ),
    );
  }

  void recordSelfieFaceDetected(bool detected) {
    state = state.copyWith(selfieFaceDetected: detected);
  }

  void recordChallengeCompleted(String challenge) {
    if (state.completedChallenges.contains(challenge)) return;
    state = state.copyWith(
      completedChallenges: [...state.completedChallenges, challenge],
    );
  }

  void recordSelfieStatus({
    String? statusMessage,
    String? errorMessage,
    bool incrementRedo = false,
    bool incrementTimeout = false,
  }) {
    state = state.copyWith(
      selfieStatusMessage: statusMessage,
      selfieError: errorMessage,
      selfieRedoCount: state.selfieRedoCount + (incrementRedo ? 1 : 0),
      selfieTimeoutCount: state.selfieTimeoutCount + (incrementTimeout ? 1 : 0),
    );
  }

  void recordSelfieCapture(String selfiePath) {
    state = state.copyWith(
      selfiePath: selfiePath,
      clearSelfieError: true,
    );
  }

  void recordMobileLivenessShadowSuccess({
    required double score,
    required double threshold,
    required double latencyMs,
  }) {
    state = state.copyWith(
      mobileLivenessShadow: state.mobileLivenessShadow.copyWith(
        attempted: true,
        available: true,
        score: score,
        threshold: threshold,
        latencyMs: latencyMs,
        clearError: true,
      ),
    );
  }

  void recordMobileLivenessShadowUnavailable(String message) {
    state = state.copyWith(
      mobileLivenessShadow: state.mobileLivenessShadow.copyWith(
        attempted: true,
        available: false,
        error: message,
        clearScore: true,
        clearThreshold: true,
        clearLatencyMs: true,
      ),
    );
  }

  void recordMobileFaceMatchSuccess(FaceEmbeddingMatchResult result) {
    state = state.copyWith(
      mobileFaceMatch: state.mobileFaceMatch.copyWith(
        attempted: true,
        available: true,
        score: result.score,
        threshold: result.threshold,
        documentLatencyMs: result.documentEmbeddingLatencyMs,
        selfieLatencyMs: result.selfieEmbeddingLatencyMs,
        documentPortraitPath: result.documentPortraitPath,
        clearError: true,
      ),
    );
  }

  void recordMobileFaceMatchUnavailable(String message) {
    state = state.copyWith(
      mobileFaceMatch: state.mobileFaceMatch.copyWith(
        attempted: true,
        available: false,
        error: message,
        clearScore: true,
        clearThreshold: true,
        clearDocumentLatencyMs: true,
        clearSelfieLatencyMs: true,
        clearDocumentPortraitPath: true,
      ),
    );
  }

  void recordProcessingStarted() {
    state = state.copyWith(
      processingStartedAt: DateTime.now(),
      clearApiError: true,
      clearResult: true,
      clearBackendSessionId: true,
      clearUploadDurationMs: true,
      clearTotalVerificationDurationMs: true,
      pollAttempts: 0,
      uploadProgressPeak: 0,
      mobileFaceMatch: state.mobileFaceMatch.copyWith(
        attempted: false,
        available: false,
        clearScore: true,
        clearThreshold: true,
        clearDocumentLatencyMs: true,
        clearSelfieLatencyMs: true,
        clearDocumentPortraitPath: true,
        clearError: true,
      ),
    );
  }

  void recordUploadProgress(double progress) {
    if (progress <= state.uploadProgressPeak) return;
    state = state.copyWith(uploadProgressPeak: progress);
  }

  void recordBackendSessionId(String sessionId) {
    state = state.copyWith(backendSessionId: sessionId);
  }

  void recordUploadCompleted(int uploadDurationMs) {
    state = state.copyWith(uploadDurationMs: uploadDurationMs);
  }

  void recordPollAttempt(int attempts) {
    state = state.copyWith(pollAttempts: attempts);
  }

  void recordVerificationResult({
    required VerificationResult result,
    required int totalDurationMs,
  }) {
    state = state.copyWith(
      result: result,
      totalVerificationDurationMs: totalDurationMs,
      backendSessionId:
          result.sessionId.isEmpty ? state.backendSessionId : result.sessionId,
      clearApiError: true,
    );
  }

  void recordApiError(String message) {
    state = state.copyWith(apiError: message);
  }

  void markExported(String exportDirectoryPath) {
    state = state.copyWith(
      exportDirectoryPath: exportDirectoryPath,
      exportedAt: DateTime.now(),
    );
  }

  void reset() {
    state = ThesisDebugReport.initial();
  }
}

final thesisDebugReportProvider =
    NotifierProvider<ThesisDebugReportNotifier, ThesisDebugReport>(
  ThesisDebugReportNotifier.new,
);
