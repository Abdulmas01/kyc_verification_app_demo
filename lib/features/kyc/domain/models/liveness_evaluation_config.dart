import '../enums/liveness_failure_policy.dart';
import '../enums/liveness_mode.dart';

class LivenessEvaluationConfig {
  const LivenessEvaluationConfig({
    required this.mode,
    required this.autoCaptureEnabled,
    required this.failurePolicy,
    this.scoreThreshold,
    this.allowRetry = true,
    this.maxRetries = 2,
  });

  final LivenessMode mode;
  final bool autoCaptureEnabled;
  final LivenessFailurePolicy failurePolicy;
  final double? scoreThreshold;
  final bool allowRetry;
  final int maxRetries;

  const LivenessEvaluationConfig.guidance()
      : mode = LivenessMode.guidance,
        autoCaptureEnabled = true,
        failurePolicy = LivenessFailurePolicy.fallbackToBackend,
        scoreThreshold = null,
        allowRetry = true,
        maxRetries = 2;

  const LivenessEvaluationConfig.shadow()
      : mode = LivenessMode.shadow,
        autoCaptureEnabled = true,
        failurePolicy = LivenessFailurePolicy.fallbackToBackend,
        scoreThreshold = null,
        allowRetry = true,
        maxRetries = 2;

  const LivenessEvaluationConfig.authoritative({
    required double threshold,
    this.autoCaptureEnabled = true,
    this.failurePolicy = LivenessFailurePolicy.failClosed,
    this.allowRetry = true,
    this.maxRetries = 2,
  })  : mode = LivenessMode.authoritative,
        scoreThreshold = threshold;

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'auto_capture_enabled': autoCaptureEnabled,
      'failure_policy': failurePolicy.name,
      'score_threshold': scoreThreshold,
      'allow_retry': allowRetry,
      'max_retries': maxRetries,
    };
  }

  factory LivenessEvaluationConfig.fromJson(Map<String, dynamic> json) {
    return LivenessEvaluationConfig(
      mode: _parseMode(json['mode']),
      autoCaptureEnabled: json['auto_capture_enabled'] != false,
      failurePolicy: _parseFailurePolicy(json['failure_policy']),
      scoreThreshold: _readDouble(json['score_threshold']),
      allowRetry: json['allow_retry'] != false,
      maxRetries: _readInt(json['max_retries']) ?? 2,
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

  static LivenessFailurePolicy _parseFailurePolicy(Object? value) {
    switch ((value ?? '').toString()) {
      case 'failClosed':
        return LivenessFailurePolicy.failClosed;
      case 'failOpen':
        return LivenessFailurePolicy.failOpen;
      case 'fallbackToBackend':
        return LivenessFailurePolicy.fallbackToBackend;
      default:
        return LivenessFailurePolicy.fallbackToBackend;
    }
  }

  static double? _readDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _readInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
