import '../enums/verification_decision.dart';

class VerificationResult {
  final VerificationDecision decision;
  final double riskScore;
  final List<String> reasonCodes;

  const VerificationResult({
    required this.decision,
    required this.riskScore,
    required this.reasonCodes,
  });

  factory VerificationResult.demo() {
    return const VerificationResult(
      decision: VerificationDecision.accept,
      riskScore: 0.08,
      reasonCodes: [],
    );
  }
}
