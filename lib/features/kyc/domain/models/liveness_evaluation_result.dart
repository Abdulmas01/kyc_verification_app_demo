import '../enums/liveness_mode.dart';
import '../enums/liveness_reason_code.dart';
import '../enums/liveness_status.dart';

class LivenessEvaluationResult {
  const LivenessEvaluationResult({
    required this.mode,
    required this.status,
    required this.reasonCode,
    required this.modelRan,
    this.score,
    this.threshold,
    this.latencyMs,
    this.retryAllowed,
    this.metadata = const {},
  });

  final LivenessMode mode;
  final LivenessStatus status;
  final LivenessReasonCode reasonCode;
  final bool modelRan;
  final double? score;
  final double? threshold;
  final double? latencyMs;
  final bool? retryAllowed;
  final Map<String, dynamic> metadata;

  bool get isSpoofDecision =>
      reasonCode == LivenessReasonCode.spoofSuspected &&
      status == LivenessStatus.failed &&
      modelRan;

  bool get isRuntimeProblem =>
      status == LivenessStatus.runtimeFailed || !modelRan;

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'status': status.name,
      'reason_code': reasonCode.name,
      'model_ran': modelRan,
      'score': score,
      'threshold': threshold,
      'latency_ms': latencyMs,
      'retry_allowed': retryAllowed,
      'metadata': metadata,
    };
  }

  factory LivenessEvaluationResult.fromJson(Map<String, dynamic> json) {
    return LivenessEvaluationResult(
      mode: _parseMode(json['mode']),
      status: _parseStatus(json['status']),
      reasonCode: _parseReasonCode(json['reason_code']),
      modelRan: json['model_ran'] == true,
      score: _readDouble(json['score']),
      threshold: _readDouble(json['threshold']),
      latencyMs: _readDouble(json['latency_ms']),
      retryAllowed: _readBool(json['retry_allowed']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
    );
  }

  factory LivenessEvaluationResult.livePassed({
    required LivenessMode mode,
    required double score,
    required double threshold,
    double? latencyMs,
    bool? retryAllowed,
    Map<String, dynamic> metadata = const {},
  }) {
    return LivenessEvaluationResult(
      mode: mode,
      status: LivenessStatus.passed,
      reasonCode: LivenessReasonCode.livePassed,
      modelRan: true,
      score: score,
      threshold: threshold,
      latencyMs: latencyMs,
      retryAllowed: retryAllowed,
      metadata: metadata,
    );
  }

  factory LivenessEvaluationResult.spoofSuspected({
    required LivenessMode mode,
    required double score,
    required double threshold,
    double? latencyMs,
    bool? retryAllowed,
    Map<String, dynamic> metadata = const {},
  }) {
    return LivenessEvaluationResult(
      mode: mode,
      status: LivenessStatus.failed,
      reasonCode: LivenessReasonCode.spoofSuspected,
      modelRan: true,
      score: score,
      threshold: threshold,
      latencyMs: latencyMs,
      retryAllowed: retryAllowed,
      metadata: metadata,
    );
  }

  factory LivenessEvaluationResult.runtimeFailed({
    required LivenessMode mode,
    required LivenessReasonCode reasonCode,
    bool? retryAllowed,
    Map<String, dynamic> metadata = const {},
  }) {
    return LivenessEvaluationResult(
      mode: mode,
      status: LivenessStatus.runtimeFailed,
      reasonCode: reasonCode,
      modelRan: false,
      retryAllowed: retryAllowed,
      metadata: metadata,
    );
  }

  factory LivenessEvaluationResult.needsBackendReview({
    required LivenessMode mode,
    required LivenessReasonCode reasonCode,
    double? score,
    double? threshold,
    double? latencyMs,
    bool? retryAllowed,
    Map<String, dynamic> metadata = const {},
  }) {
    return LivenessEvaluationResult(
      mode: mode,
      status: LivenessStatus.needsBackendReview,
      reasonCode: reasonCode,
      modelRan: score != null,
      score: score,
      threshold: threshold,
      latencyMs: latencyMs,
      retryAllowed: retryAllowed,
      metadata: metadata,
    );
  }

  static LivenessMode _parseMode(Object? value) {
    switch ((value ?? '').toString()) {
      case 'guidance':
        return LivenessMode.guidance;
      case 'shadow':
        return LivenessMode.shadow;
      case 'authoritative':
        return LivenessMode.authoritative;
      default:
        return LivenessMode.guidance;
    }
  }

  static LivenessStatus _parseStatus(Object? value) {
    switch ((value ?? '').toString()) {
      case 'passed':
        return LivenessStatus.passed;
      case 'failed':
        return LivenessStatus.failed;
      case 'runtimeFailed':
        return LivenessStatus.runtimeFailed;
      case 'needsBackendReview':
        return LivenessStatus.needsBackendReview;
      case 'cancelled':
        return LivenessStatus.cancelled;
      default:
        return LivenessStatus.runtimeFailed;
    }
  }

  static LivenessReasonCode _parseReasonCode(Object? value) {
    switch ((value ?? '').toString()) {
      case 'livePassed':
        return LivenessReasonCode.livePassed;
      case 'spoofSuspected':
        return LivenessReasonCode.spoofSuspected;
      case 'runtimeFailed':
        return LivenessReasonCode.runtimeFailed;
      case 'modelUnavailable':
        return LivenessReasonCode.modelUnavailable;
      case 'faceNotFound':
        return LivenessReasonCode.faceNotFound;
      case 'multipleFaces':
        return LivenessReasonCode.multipleFaces;
      case 'faceNotClear':
        return LivenessReasonCode.faceNotClear;
      case 'timedOut':
        return LivenessReasonCode.timedOut;
      case 'cancelled':
        return LivenessReasonCode.cancelled;
      case 'needsBackendReview':
        return LivenessReasonCode.needsBackendReview;
      default:
        return LivenessReasonCode.runtimeFailed;
    }
  }

  static double? _readDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool? _readBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return null;
  }
}
