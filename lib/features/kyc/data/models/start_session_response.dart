class StartSessionResponse {
  final String id;
  final String sessionToken;
  final String expiresAt;
  final String workflowKey;
  final String sourceType;
  final String subjectReference;
  final String subjectExternalId;
  final Map<String, dynamic> subjectSummary;

  const StartSessionResponse({
    required this.id,
    required this.sessionToken,
    required this.expiresAt,
    required this.workflowKey,
    required this.sourceType,
    required this.subjectReference,
    required this.subjectExternalId,
    required this.subjectSummary,
  });

  factory StartSessionResponse.fromJson(Map<String, dynamic> json) {
    return StartSessionResponse(
      id: (json['id'] ?? '').toString(),
      sessionToken: json['session_token'] ?? '',
      expiresAt: (json['expires_at'] ?? '').toString(),
      workflowKey: (json['workflow_key'] ?? '').toString(),
      sourceType: (json['source_type'] ?? '').toString(),
      subjectReference: (json['subject_reference'] ?? '').toString(),
      subjectExternalId: (json['subject_external_id'] ?? '').toString(),
      subjectSummary: Map<String, dynamic>.from(
        (json['subject_summary'] as Map?) ?? const {},
      ),
    );
  }
}
