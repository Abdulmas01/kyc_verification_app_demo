class UploadResponse {
  final String sessionId;
  final int estimatedWaitMs;

  const UploadResponse({
    required this.sessionId,
    required this.estimatedWaitMs,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      sessionId: json['session_id'] ?? '',
      estimatedWaitMs: json['estimated_wait_ms'] ?? 1500,
    );
  }
}
