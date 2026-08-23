class FaceEmbeddingMatchResult {
  const FaceEmbeddingMatchResult({
    required this.score,
    required this.threshold,
    required this.passedThreshold,
    required this.documentEmbeddingLatencyMs,
    required this.selfieEmbeddingLatencyMs,
    required this.documentPortraitPath,
  });

  final double score;
  final double threshold;
  final bool passedThreshold;
  final double documentEmbeddingLatencyMs;
  final double selfieEmbeddingLatencyMs;
  final String documentPortraitPath;
}
