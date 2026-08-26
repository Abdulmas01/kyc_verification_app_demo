class UploadResponse {
  final String status;

  const UploadResponse({
    required this.status,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      status: (json['status'] ?? '').toString(),
    );
  }
}
