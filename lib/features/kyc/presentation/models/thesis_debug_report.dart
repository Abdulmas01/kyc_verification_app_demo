import 'package:kyc_verification_app_demo/features/kyc/domain/models/verification_result.dart';

class ThesisDebugReport {
  const ThesisDebugReport({
    required this.runId,
    required this.startedAt,
    this.documentConfig = const {},
    this.selfieConfig = const {},
    this.documentStatusMessage,
    this.documentQualityConfidence,
    this.documentQualityAccepted,
    this.documentQualityLabel,
    this.documentAverageInferenceMs,
    this.documentInferenceSamples = 0,
    this.documentFrameStride,
    this.documentAutoCaptureTriggered = false,
    this.documentDetected = false,
    this.documentError,
    this.documentPath,
    this.normalizedDocumentPath,
    this.selfieFaceDetected = false,
    this.selfieStatusMessage,
    this.selfieError,
    this.selfiePath,
    this.selfieRedoCount = 0,
    this.selfieTimeoutCount = 0,
    this.completedChallenges = const [],
    this.mobileLivenessShadowEnabled = false,
    this.mobileLivenessShadowAttempted = false,
    this.mobileLivenessShadowAvailable = false,
    this.mobileLivenessShadowScore,
    this.mobileLivenessShadowThreshold,
    this.mobileLivenessShadowLatencyMs,
    this.mobileLivenessShadowError,
    this.processingStartedAt,
    this.uploadProgressPeak = 0,
    this.uploadDurationMs,
    this.totalVerificationDurationMs,
    this.pollAttempts = 0,
    this.backendSessionId,
    this.apiError,
    this.result,
    this.exportDirectoryPath,
    this.exportedAt,
  });

  final String runId;
  final DateTime startedAt;
  final Map<String, dynamic> documentConfig;
  final Map<String, dynamic> selfieConfig;
  final String? documentStatusMessage;
  final double? documentQualityConfidence;
  final bool? documentQualityAccepted;
  final String? documentQualityLabel;
  final double? documentAverageInferenceMs;
  final int documentInferenceSamples;
  final int? documentFrameStride;
  final bool documentAutoCaptureTriggered;
  final bool documentDetected;
  final String? documentError;
  final String? documentPath;
  final String? normalizedDocumentPath;
  final bool selfieFaceDetected;
  final String? selfieStatusMessage;
  final String? selfieError;
  final String? selfiePath;
  final int selfieRedoCount;
  final int selfieTimeoutCount;
  final List<String> completedChallenges;
  final bool mobileLivenessShadowEnabled;
  final bool mobileLivenessShadowAttempted;
  final bool mobileLivenessShadowAvailable;
  final double? mobileLivenessShadowScore;
  final double? mobileLivenessShadowThreshold;
  final double? mobileLivenessShadowLatencyMs;
  final String? mobileLivenessShadowError;
  final DateTime? processingStartedAt;
  final double uploadProgressPeak;
  final int? uploadDurationMs;
  final int? totalVerificationDurationMs;
  final int pollAttempts;
  final String? backendSessionId;
  final String? apiError;
  final VerificationResult? result;
  final String? exportDirectoryPath;
  final DateTime? exportedAt;

  factory ThesisDebugReport.initial() {
    return ThesisDebugReport(
      runId: 'kyc_${DateTime.now().millisecondsSinceEpoch}',
      startedAt: DateTime.now(),
    );
  }

  ThesisDebugReport copyWith({
    String? runId,
    DateTime? startedAt,
    Map<String, dynamic>? documentConfig,
    Map<String, dynamic>? selfieConfig,
    String? documentStatusMessage,
    bool clearDocumentStatusMessage = false,
    double? documentQualityConfidence,
    bool clearDocumentQualityConfidence = false,
    bool? documentQualityAccepted,
    bool clearDocumentQualityAccepted = false,
    String? documentQualityLabel,
    bool clearDocumentQualityLabel = false,
    double? documentAverageInferenceMs,
    bool clearDocumentAverageInferenceMs = false,
    int? documentInferenceSamples,
    int? documentFrameStride,
    bool clearDocumentFrameStride = false,
    bool? documentAutoCaptureTriggered,
    bool? documentDetected,
    String? documentError,
    bool clearDocumentError = false,
    String? documentPath,
    bool clearDocumentPath = false,
    String? normalizedDocumentPath,
    bool clearNormalizedDocumentPath = false,
    bool? selfieFaceDetected,
    String? selfieStatusMessage,
    bool clearSelfieStatusMessage = false,
    String? selfieError,
    bool clearSelfieError = false,
    String? selfiePath,
    bool clearSelfiePath = false,
    int? selfieRedoCount,
    int? selfieTimeoutCount,
    List<String>? completedChallenges,
    bool? mobileLivenessShadowEnabled,
    bool? mobileLivenessShadowAttempted,
    bool? mobileLivenessShadowAvailable,
    double? mobileLivenessShadowScore,
    bool clearMobileLivenessShadowScore = false,
    double? mobileLivenessShadowThreshold,
    bool clearMobileLivenessShadowThreshold = false,
    double? mobileLivenessShadowLatencyMs,
    bool clearMobileLivenessShadowLatencyMs = false,
    String? mobileLivenessShadowError,
    bool clearMobileLivenessShadowError = false,
    DateTime? processingStartedAt,
    bool clearProcessingStartedAt = false,
    double? uploadProgressPeak,
    int? uploadDurationMs,
    bool clearUploadDurationMs = false,
    int? totalVerificationDurationMs,
    bool clearTotalVerificationDurationMs = false,
    int? pollAttempts,
    String? backendSessionId,
    bool clearBackendSessionId = false,
    String? apiError,
    bool clearApiError = false,
    VerificationResult? result,
    bool clearResult = false,
    String? exportDirectoryPath,
    bool clearExportDirectoryPath = false,
    DateTime? exportedAt,
    bool clearExportedAt = false,
  }) {
    return ThesisDebugReport(
      runId: runId ?? this.runId,
      startedAt: startedAt ?? this.startedAt,
      documentConfig: documentConfig ?? this.documentConfig,
      selfieConfig: selfieConfig ?? this.selfieConfig,
      documentStatusMessage: clearDocumentStatusMessage
          ? null
          : (documentStatusMessage ?? this.documentStatusMessage),
      documentQualityConfidence: clearDocumentQualityConfidence
          ? null
          : (documentQualityConfidence ?? this.documentQualityConfidence),
      documentQualityAccepted: clearDocumentQualityAccepted
          ? null
          : (documentQualityAccepted ?? this.documentQualityAccepted),
      documentQualityLabel: clearDocumentQualityLabel
          ? null
          : (documentQualityLabel ?? this.documentQualityLabel),
      documentAverageInferenceMs: clearDocumentAverageInferenceMs
          ? null
          : (documentAverageInferenceMs ?? this.documentAverageInferenceMs),
      documentInferenceSamples:
          documentInferenceSamples ?? this.documentInferenceSamples,
      documentFrameStride: clearDocumentFrameStride
          ? null
          : (documentFrameStride ?? this.documentFrameStride),
      documentAutoCaptureTriggered:
          documentAutoCaptureTriggered ?? this.documentAutoCaptureTriggered,
      documentDetected: documentDetected ?? this.documentDetected,
      documentError:
          clearDocumentError ? null : (documentError ?? this.documentError),
      documentPath:
          clearDocumentPath ? null : (documentPath ?? this.documentPath),
      normalizedDocumentPath: clearNormalizedDocumentPath
          ? null
          : (normalizedDocumentPath ?? this.normalizedDocumentPath),
      selfieFaceDetected: selfieFaceDetected ?? this.selfieFaceDetected,
      selfieStatusMessage: clearSelfieStatusMessage
          ? null
          : (selfieStatusMessage ?? this.selfieStatusMessage),
      selfieError: clearSelfieError ? null : (selfieError ?? this.selfieError),
      selfiePath: clearSelfiePath ? null : (selfiePath ?? this.selfiePath),
      selfieRedoCount: selfieRedoCount ?? this.selfieRedoCount,
      selfieTimeoutCount: selfieTimeoutCount ?? this.selfieTimeoutCount,
      completedChallenges: completedChallenges ?? this.completedChallenges,
      mobileLivenessShadowEnabled:
          mobileLivenessShadowEnabled ?? this.mobileLivenessShadowEnabled,
      mobileLivenessShadowAttempted:
          mobileLivenessShadowAttempted ?? this.mobileLivenessShadowAttempted,
      mobileLivenessShadowAvailable:
          mobileLivenessShadowAvailable ?? this.mobileLivenessShadowAvailable,
      mobileLivenessShadowScore: clearMobileLivenessShadowScore
          ? null
          : (mobileLivenessShadowScore ?? this.mobileLivenessShadowScore),
      mobileLivenessShadowThreshold: clearMobileLivenessShadowThreshold
          ? null
          : (mobileLivenessShadowThreshold ??
              this.mobileLivenessShadowThreshold),
      mobileLivenessShadowLatencyMs: clearMobileLivenessShadowLatencyMs
          ? null
          : (mobileLivenessShadowLatencyMs ??
              this.mobileLivenessShadowLatencyMs),
      mobileLivenessShadowError: clearMobileLivenessShadowError
          ? null
          : (mobileLivenessShadowError ?? this.mobileLivenessShadowError),
      processingStartedAt: clearProcessingStartedAt
          ? null
          : (processingStartedAt ?? this.processingStartedAt),
      uploadProgressPeak: uploadProgressPeak ?? this.uploadProgressPeak,
      uploadDurationMs: clearUploadDurationMs
          ? null
          : (uploadDurationMs ?? this.uploadDurationMs),
      totalVerificationDurationMs: clearTotalVerificationDurationMs
          ? null
          : (totalVerificationDurationMs ?? this.totalVerificationDurationMs),
      pollAttempts: pollAttempts ?? this.pollAttempts,
      backendSessionId: clearBackendSessionId
          ? null
          : (backendSessionId ?? this.backendSessionId),
      apiError: clearApiError ? null : (apiError ?? this.apiError),
      result: clearResult ? null : (result ?? this.result),
      exportDirectoryPath: clearExportDirectoryPath
          ? null
          : (exportDirectoryPath ?? this.exportDirectoryPath),
      exportedAt: clearExportedAt ? null : (exportedAt ?? this.exportedAt),
    );
  }

  Map<String, dynamic> toJson({
    String? exportDirectoryPath,
    Map<String, dynamic>? supportingFiles,
  }) {
    return {
      'run_id': runId,
      'started_at': startedAt.toIso8601String(),
      if (exportedAt != null) 'exported_at': exportedAt!.toIso8601String(),
      if ((exportDirectoryPath ?? this.exportDirectoryPath) != null)
        'export_directory': exportDirectoryPath ?? this.exportDirectoryPath,
      'capture': {
        'document': {
          'config': documentConfig,
          'status_message': documentStatusMessage,
          'quality_label': documentQualityLabel,
          'quality_confidence': documentQualityConfidence,
          'quality_accepted': documentQualityAccepted,
          'average_inference_ms': documentAverageInferenceMs,
          'inference_samples': documentInferenceSamples,
          'frame_stride': documentFrameStride,
          'auto_capture_triggered': documentAutoCaptureTriggered,
          'document_detected': documentDetected,
          'error': documentError,
          'source_path': documentPath,
          'normalized_path': normalizedDocumentPath,
        },
        'selfie_liveness': {
          'config': selfieConfig,
          'face_detected': selfieFaceDetected,
          'status_message': selfieStatusMessage,
          'error': selfieError,
          'selfie_path': selfiePath,
          'redo_count': selfieRedoCount,
          'timeout_count': selfieTimeoutCount,
          'completed_challenges': completedChallenges,
          'mobile_shadow': {
            'enabled': mobileLivenessShadowEnabled,
            'attempted': mobileLivenessShadowAttempted,
            'available': mobileLivenessShadowAvailable,
            'score': mobileLivenessShadowScore,
            'threshold': mobileLivenessShadowThreshold,
            'latency_ms': mobileLivenessShadowLatencyMs,
            'error': mobileLivenessShadowError,
          },
        },
      },
      'processing': {
        'started_at': processingStartedAt?.toIso8601String(),
        'backend_session_id': backendSessionId,
        'upload_progress_peak': uploadProgressPeak,
        'upload_duration_ms': uploadDurationMs,
        'total_verification_duration_ms': totalVerificationDurationMs,
        'poll_attempts': pollAttempts,
        'api_error': apiError,
      },
      'result': result?.toJson(),
      if (supportingFiles != null) 'supporting_files': supportingFiles,
    };
  }
}
