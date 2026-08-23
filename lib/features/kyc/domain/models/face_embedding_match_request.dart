import '../enums/document_face_source_type.dart';

class FaceEmbeddingMatchRequest {
  const FaceEmbeddingMatchRequest({
    required this.documentPath,
    required this.selfiePath,
    this.documentType = DocumentFaceSourceType.unknown,
  });

  final String documentPath;
  final String selfiePath;
  final DocumentFaceSourceType documentType;
}
