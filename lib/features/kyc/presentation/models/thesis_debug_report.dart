import 'package:kyc_verification_app_demo/features/kyc/domain/models/verification_result.dart';

class DocumentQualityDebugSample {
  const DocumentQualityDebugSample({
    this.directoryPath,
    this.fullFramePath,
    this.modelInputPath,
    this.metadataPath,
  });

  final String? directoryPath;
  final String? fullFramePath;
  final String? modelInputPath;
  final String? metadataPath;

  bool get isEmpty =>
      directoryPath == null &&
      fullFramePath == null &&
      modelInputPath == null &&
      metadataPath == null;

  DocumentQualityDebugSample copyWith({
    String? directoryPath,
    bool clearDirectoryPath = false,
    String? fullFramePath,
    bool clearFullFramePath = false,
    String? modelInputPath,
    bool clearModelInputPath = false,
    String? metadataPath,
    bool clearMetadataPath = false,
  }) {
    return DocumentQualityDebugSample(
      directoryPath:
          clearDirectoryPath ? null : (directoryPath ?? this.directoryPath),
      fullFramePath:
          clearFullFramePath ? null : (fullFramePath ?? this.fullFramePath),
      modelInputPath:
          clearModelInputPath ? null : (modelInputPath ?? this.modelInputPath),
      metadataPath:
          clearMetadataPath ? null : (metadataPath ?? this.metadataPath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'directory_path': directoryPath,
      'full_frame_path': fullFramePath,
      'model_input_path': modelInputPath,
      'metadata_path': metadataPath,
    };
  }
}

class MobileLivenessShadowDebug {
  const MobileLivenessShadowDebug({
    this.enabled = false,
    this.attempted = false,
    this.available = false,
    this.score,
    this.threshold,
    this.latencyMs,
    this.error,
  });

  final bool enabled;
  final bool attempted;
  final bool available;
  final double? score;
  final double? threshold;
  final double? latencyMs;
  final String? error;

  MobileLivenessShadowDebug copyWith({
    bool? enabled,
    bool? attempted,
    bool? available,
    double? score,
    bool clearScore = false,
    double? threshold,
    bool clearThreshold = false,
    double? latencyMs,
    bool clearLatencyMs = false,
    String? error,
    bool clearError = false,
  }) {
    return MobileLivenessShadowDebug(
      enabled: enabled ?? this.enabled,
      attempted: attempted ?? this.attempted,
      available: available ?? this.available,
      score: clearScore ? null : (score ?? this.score),
      threshold: clearThreshold ? null : (threshold ?? this.threshold),
      latencyMs: clearLatencyMs ? null : (latencyMs ?? this.latencyMs),
      error: clearError ? null : (error ?? this.error),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'attempted': attempted,
      'available': available,
      'score': score,
      'threshold': threshold,
      'latency_ms': latencyMs,
      'error': error,
    };
  }
}

class MobileFaceMatchDebug {
  const MobileFaceMatchDebug({
    this.attempted = false,
    this.available = false,
    this.score,
    this.threshold,
    this.documentLatencyMs,
    this.selfieLatencyMs,
    this.documentPortraitPath,
    this.error,
  });

  final bool attempted;
  final bool available;
  final double? score;
  final double? threshold;
  final double? documentLatencyMs;
  final double? selfieLatencyMs;
  final String? documentPortraitPath;
  final String? error;

  MobileFaceMatchDebug copyWith({
    bool? attempted,
    bool? available,
    double? score,
    bool clearScore = false,
    double? threshold,
    bool clearThreshold = false,
    double? documentLatencyMs,
    bool clearDocumentLatencyMs = false,
    double? selfieLatencyMs,
    bool clearSelfieLatencyMs = false,
    String? documentPortraitPath,
    bool clearDocumentPortraitPath = false,
    String? error,
    bool clearError = false,
  }) {
    return MobileFaceMatchDebug(
      attempted: attempted ?? this.attempted,
      available: available ?? this.available,
      score: clearScore ? null : (score ?? this.score),
      threshold: clearThreshold ? null : (threshold ?? this.threshold),
      documentLatencyMs: clearDocumentLatencyMs
          ? null
          : (documentLatencyMs ?? this.documentLatencyMs),
      selfieLatencyMs: clearSelfieLatencyMs
          ? null
          : (selfieLatencyMs ?? this.selfieLatencyMs),
      documentPortraitPath: clearDocumentPortraitPath
          ? null
          : (documentPortraitPath ?? this.documentPortraitPath),
      error: clearError ? null : (error ?? this.error),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attempted': attempted,
      'available': available,
      'score': score,
      'threshold': threshold,
      'document_latency_ms': documentLatencyMs,
      'selfie_latency_ms': selfieLatencyMs,
      'document_portrait_path': documentPortraitPath,
      'error': error,
    };
  }
}

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
    this.documentQualityDebugSample = const DocumentQualityDebugSample(),
    this.selfieFaceDetected = false,
    this.selfieStatusMessage,
    this.selfieError,
    this.selfiePath,
    this.selfieRedoCount = 0,
    this.selfieTimeoutCount = 0,
    this.completedChallenges = const [],
    this.mobileLivenessShadow = const MobileLivenessShadowDebug(),
    this.mobileFaceMatch = const MobileFaceMatchDebug(),
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
  final DocumentQualityDebugSample documentQualityDebugSample;
  final bool selfieFaceDetected;
  final String? selfieStatusMessage;
  final String? selfieError;
  final String? selfiePath;
  final int selfieRedoCount;
  final int selfieTimeoutCount;
  final List<String> completedChallenges;
  final MobileLivenessShadowDebug mobileLivenessShadow;
  final MobileFaceMatchDebug mobileFaceMatch;
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

  String? get documentQualityDebugSampleDirectoryPath =>
      documentQualityDebugSample.directoryPath;
  String? get documentQualityDebugFullFramePath =>
      documentQualityDebugSample.fullFramePath;
  String? get documentQualityDebugModelInputPath =>
      documentQualityDebugSample.modelInputPath;
  String? get documentQualityDebugMetadataPath =>
      documentQualityDebugSample.metadataPath;

  bool get mobileLivenessShadowEnabled => mobileLivenessShadow.enabled;
  bool get mobileLivenessShadowAttempted => mobileLivenessShadow.attempted;
  bool get mobileLivenessShadowAvailable => mobileLivenessShadow.available;
  double? get mobileLivenessShadowScore => mobileLivenessShadow.score;
  double? get mobileLivenessShadowThreshold => mobileLivenessShadow.threshold;
  double? get mobileLivenessShadowLatencyMs => mobileLivenessShadow.latencyMs;
  String? get mobileLivenessShadowError => mobileLivenessShadow.error;

  bool get mobileFaceMatchAttempted => mobileFaceMatch.attempted;
  bool get mobileFaceMatchAvailable => mobileFaceMatch.available;
  double? get mobileFaceMatchScore => mobileFaceMatch.score;
  double? get mobileFaceMatchThreshold => mobileFaceMatch.threshold;
  double? get mobileFaceMatchDocumentLatencyMs =>
      mobileFaceMatch.documentLatencyMs;
  double? get mobileFaceMatchSelfieLatencyMs => mobileFaceMatch.selfieLatencyMs;
  String? get mobileFaceMatchPortraitPath =>
      mobileFaceMatch.documentPortraitPath;
  String? get mobileFaceMatchError => mobileFaceMatch.error;

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
    DocumentQualityDebugSample? documentQualityDebugSample,
    bool clearDocumentQualityDebugSample = false,
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
    MobileLivenessShadowDebug? mobileLivenessShadow,
    MobileFaceMatchDebug? mobileFaceMatch,
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
      documentQualityDebugSample: clearDocumentQualityDebugSample
          ? const DocumentQualityDebugSample()
          : (documentQualityDebugSample ?? this.documentQualityDebugSample),
      selfieFaceDetected: selfieFaceDetected ?? this.selfieFaceDetected,
      selfieStatusMessage: clearSelfieStatusMessage
          ? null
          : (selfieStatusMessage ?? this.selfieStatusMessage),
      selfieError: clearSelfieError ? null : (selfieError ?? this.selfieError),
      selfiePath: clearSelfiePath ? null : (selfiePath ?? this.selfiePath),
      selfieRedoCount: selfieRedoCount ?? this.selfieRedoCount,
      selfieTimeoutCount: selfieTimeoutCount ?? this.selfieTimeoutCount,
      completedChallenges: completedChallenges ?? this.completedChallenges,
      mobileLivenessShadow: mobileLivenessShadow ?? this.mobileLivenessShadow,
      mobileFaceMatch: mobileFaceMatch ?? this.mobileFaceMatch,
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
          'quality_debug_sample': documentQualityDebugSample.toJson(),
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
          'mobile_shadow': mobileLivenessShadow.toJson(),
          'mobile_face_match': mobileFaceMatch.toJson(),
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
