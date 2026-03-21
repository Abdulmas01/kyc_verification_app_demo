import '../enums/verification_decision.dart';

class VerificationResult {
  final String sessionId;
  final VerificationDecision decision;
  final double riskScore;
  final List<String> reasonCodes;

  const VerificationResult({
    required this.sessionId,
    required this.decision,
    required this.riskScore,
    required this.reasonCodes,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    final decision = (json['decision'] ?? '').toString().toUpperCase();
    return VerificationResult(
      sessionId: json['session_id'] ?? '',
      decision: _parseDecision(decision),
      riskScore: (json['risk_score'] ?? 0).toDouble(),
      reasonCodes: List<String>.from(json['reason_codes'] ?? []),
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
}
