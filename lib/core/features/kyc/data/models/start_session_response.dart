class StartSessionResponse {
  final String sessionToken;
  final int expiresIn;

  const StartSessionResponse({
    required this.sessionToken,
    required this.expiresIn,
  });

  factory StartSessionResponse.fromJson(Map<String, dynamic> json) {
    return StartSessionResponse(
      sessionToken: json['session_token'] ?? '',
      expiresIn: json['expires_in'] ?? 0,
    );
  }
}
