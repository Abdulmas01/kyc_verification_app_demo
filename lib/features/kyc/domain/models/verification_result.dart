import '../enums/verification_decision.dart';

class VerificationResult {
  final String sessionId;
  final VerificationDecision decision;
  final double riskScore;
  final List<String> reasonCodes;
  final double? faceSimilarity;
  final double? livenessScore;
  final double? ocrConfidence;
  final double? fieldValidScore;
  final double? faceAreaRatio;
  final double? qualityScore;
  final Map<String, dynamic> rawPayload;

  const VerificationResult({
    required this.sessionId,
    required this.decision,
    required this.riskScore,
    required this.reasonCodes,
    this.faceSimilarity,
    this.livenessScore,
    this.ocrConfidence,
    this.fieldValidScore,
    this.faceAreaRatio,
    this.qualityScore,
    this.rawPayload = const {},
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    final decision = (json['decision'] ?? '').toString().toUpperCase();
    return VerificationResult(
      sessionId: json['session_id'] ?? '',
      decision: _parseDecision(decision),
      riskScore: (json['risk_score'] ?? 0).toDouble(),
      reasonCodes: List<String>.from(json['reason_codes'] ?? []),
      faceSimilarity: _readDouble(json['face_similarity']),
      livenessScore: _readDouble(json['liveness_score']),
      ocrConfidence: _readDouble(json['ocr_confidence']),
      fieldValidScore: _readDouble(json['field_valid_score']),
      faceAreaRatio: _readDouble(json['face_area_ratio']),
      qualityScore: _readDouble(json['quality_score']),
      rawPayload: Map<String, dynamic>.from(json),
    );
  }

  factory VerificationResult.demo() {
    return const VerificationResult(
      sessionId: 'demo',
      decision: VerificationDecision.accept,
      riskScore: 0.08,
      reasonCodes: [],
    );
  }

  Map<String, dynamic> toJson() {
    if (rawPayload.isNotEmpty) {
      return Map<String, dynamic>.from(rawPayload);
    }
    return {
      'session_id': sessionId,
      'decision': _decisionToApiValue(decision),
      'risk_score': riskScore,
      'reason_codes': reasonCodes,
      if (faceSimilarity != null) 'face_similarity': faceSimilarity,
      if (livenessScore != null) 'liveness_score': livenessScore,
      if (ocrConfidence != null) 'ocr_confidence': ocrConfidence,
      if (fieldValidScore != null) 'field_valid_score': fieldValidScore,
      if (faceAreaRatio != null) 'face_area_ratio': faceAreaRatio,
      if (qualityScore != null) 'quality_score': qualityScore,
    };
  }

  static VerificationDecision _parseDecision(String decision) {
    switch (decision) {
      case 'ACCEPT':
        return VerificationDecision.accept;
      case 'REJECT':
        return VerificationDecision.reject;
      case 'MANUAL_REVIEW':
        return VerificationDecision.manualReview;
      default:
        return VerificationDecision.manualReview;
    }
  }

  static double? _readDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _decisionToApiValue(VerificationDecision decision) {
    switch (decision) {
      case VerificationDecision.accept:
        return 'ACCEPT';
      case VerificationDecision.reject:
        return 'REJECT';
      case VerificationDecision.manualReview:
        return 'MANUAL_REVIEW';
    }
  }
}
