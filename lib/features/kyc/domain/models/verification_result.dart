import '../enums/verification_decision.dart';

class VerificationResult {
  final String sessionId;
  final String sessionToken;
  final String status;
  final VerificationDecision decision;
  final double? riskScore;
  final List<String> reasonCodes;
  final double? ocrConfidence;
  final double? fieldValidScore;
  final String extractedIdNumber;
  final String extractedFullName;
  final String? extractedDateOfBirth;
  final String? extractedExpiryDate;
  final String failureCode;
  final String failureMessage;
  final Map<String, dynamic> rawPayload;

  const VerificationResult({
    required this.sessionId,
    required this.sessionToken,
    required this.status,
    required this.decision,
    required this.riskScore,
    required this.reasonCodes,
    this.ocrConfidence,
    this.fieldValidScore,
    this.extractedIdNumber = '',
    this.extractedFullName = '',
    this.extractedDateOfBirth,
    this.extractedExpiryDate,
    this.failureCode = '',
    this.failureMessage = '',
    this.rawPayload = const {},
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    final decision = (json['decision'] ?? '').toString().toUpperCase();
    return VerificationResult(
      sessionId: (json['id'] ?? '').toString(),
      sessionToken: (json['session_token'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      decision: _parseDecision(decision),
      riskScore: _readDouble(json['risk_score']),
      reasonCodes: List<String>.from(json['reason_codes'] ?? []),
      ocrConfidence: _readDouble(json['ocr_confidence']),
      fieldValidScore: _readDouble(json['field_valid_score']),
      extractedIdNumber: (json['extracted_id_number'] ?? '').toString(),
      extractedFullName: (json['extracted_full_name'] ?? '').toString(),
      extractedDateOfBirth: _readString(json['extracted_date_of_birth']),
      extractedExpiryDate: _readString(json['extracted_expiry_date']),
      failureCode: (json['failure_code'] ?? '').toString(),
      failureMessage: (json['failure_message'] ?? '').toString(),
      rawPayload: Map<String, dynamic>.from(json),
    );
  }

  factory VerificationResult.demo() {
    return const VerificationResult(
      sessionId: 'demo',
      sessionToken: 'demo-token',
      status: 'completed',
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
      'id': sessionId,
      'session_token': sessionToken,
      'status': status,
      'decision': _decisionToApiValue(decision),
      'risk_score': riskScore,
      'reason_codes': reasonCodes,
      if (ocrConfidence != null) 'ocr_confidence': ocrConfidence,
      if (fieldValidScore != null) 'field_valid_score': fieldValidScore,
      'extracted_id_number': extractedIdNumber,
      'extracted_full_name': extractedFullName,
      if (extractedDateOfBirth != null)
        'extracted_date_of_birth': extractedDateOfBirth,
      if (extractedExpiryDate != null)
        'extracted_expiry_date': extractedExpiryDate,
      'failure_code': failureCode,
      'failure_message': failureMessage,
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

  static String? _readString(Object? value) {
    if (value == null) return null;
    final stringValue = value.toString();
    return stringValue.isEmpty ? null : stringValue;
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
