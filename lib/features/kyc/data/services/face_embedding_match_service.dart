import 'package:kyc_verification_app_demo/core/ml/face_embedding_model.dart';
import 'package:kyc_verification_app_demo/core/vision/document_portrait_cropper.dart';

import '../../domain/models/face_embedding_match_request.dart';
import '../../domain/models/face_embedding_match_result.dart';

class FaceEmbeddingMatchService {
  const FaceEmbeddingMatchService();

  Future<FaceEmbeddingMatchResult?> run(
    FaceEmbeddingMatchRequest request,
  ) async {
    final portraitResult = await DocumentPortraitCropper.cropFromFile(
      documentPath: request.documentPath,
      documentType: request.documentType,
    );

    final documentPrediction = await FaceEmbeddingModel.predictFromImage(
      portraitResult.croppedFace,
    );
    final selfiePrediction = await FaceEmbeddingModel.predictFromFile(
      request.selfiePath,
    );

    if (documentPrediction == null || selfiePrediction == null) {
      return null;
    }

    final score = FaceEmbeddingModel.similarityFromEmbeddings(
      documentPrediction.embedding,
      selfiePrediction.embedding,
    );
    final threshold = documentPrediction.threshold;

    return FaceEmbeddingMatchResult(
      score: score,
      threshold: threshold,
      passedThreshold: score >= threshold,
      documentEmbeddingLatencyMs: documentPrediction.latencyMs,
      selfieEmbeddingLatencyMs: selfiePrediction.latencyMs,
      documentPortraitPath: portraitResult.portraitPath,
    );
  }
}
