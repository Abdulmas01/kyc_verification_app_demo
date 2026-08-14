enum DocumentCaptureSource {
  objectDetector,
  guideFallback,
}

class DocumentCaptureResult {
  const DocumentCaptureResult({
    required this.originalPath,
    required this.normalizedPath,
    required this.captureSource,
  });

  final String originalPath;
  final String normalizedPath;
  final DocumentCaptureSource captureSource;

  bool get usedGuideCropFallback =>
      captureSource == DocumentCaptureSource.guideFallback;
}
