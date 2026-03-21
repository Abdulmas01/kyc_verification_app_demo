class KycCaptureBundle {
  final String documentPath;
  final String? selfiePath;

  const KycCaptureBundle({
    required this.documentPath,
    this.selfiePath,
  });

  KycCaptureBundle copyWith({
    String? documentPath,
    String? selfiePath,
  }) {
    return KycCaptureBundle(
      documentPath: documentPath ?? this.documentPath,
      selfiePath: selfiePath ?? this.selfiePath,
    );
  }
}
