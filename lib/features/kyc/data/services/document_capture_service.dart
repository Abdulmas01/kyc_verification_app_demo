import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:kyc_verification_app_demo/core/utils/image_utils.dart';

import '../../domain/models/document_capture_request.dart';
import '../../domain/models/document_capture_result.dart';

class DocumentCaptureService {
  const DocumentCaptureService();

  Future<DocumentCaptureResult> captureAndNormalize(
    DocumentCaptureRequest request,
  ) async {
    final file = await request.controller.takePicture();
    final inputImage = InputImage.fromFilePath(file.path);
    final objects = await request.objectDetector.processImage(inputImage);
    final detectedObject = objects.isNotEmpty ? objects.first : null;
    final usedGuideCropFallback = detectedObject == null;

    final normalized = await ImageUtils.normalizeDocumentImage(
      inputPath: file.path,
      boundingBox: detectedObject?.boundingBox,
      fallbackToCenteredGuideCrop: true,
    );

    return DocumentCaptureResult(
      originalPath: file.path,
      normalizedPath: normalized.path,
      captureSource: usedGuideCropFallback
          ? DocumentCaptureSource.guideFallback
          : DocumentCaptureSource.objectDetector,
    );
  }
}
