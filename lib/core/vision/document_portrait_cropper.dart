import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../features/kyc/domain/enums/document_face_source_type.dart';
import '../ml/face_embedding_contract.dart';
import 'single_face_cropper.dart';

class DocumentPortraitCropResult {
  const DocumentPortraitCropResult({
    required this.portraitPath,
    required this.croppedFace,
  });

  final String portraitPath;
  final img.Image croppedFace;
}

class DocumentPortraitCropper {
  static Future<DocumentPortraitCropResult> cropFromFile({
    required String documentPath,
    required DocumentFaceSourceType documentType,
  }) async {
    final contract = await FaceEmbeddingContract.load();
    final bytes = await File(documentPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unable to decode document image for portrait crop.');
    }

    final oriented = img.bakeOrientation(decoded);
    final roi = contract.portraitRoiFor(documentType);
    final left = (oriented.width * roi.$1).floor().clamp(0, oriented.width - 1);
    final right = (oriented.width * roi.$2).ceil().clamp(1, oriented.width);
    final top =
        (oriented.height * roi.$3).floor().clamp(0, oriented.height - 1);
    final bottom = (oriented.height * roi.$4).ceil().clamp(1, oriented.height);

    final width = math.max(1, right - left);
    final height = math.max(1, bottom - top);
    final portraitRegion = img.copyCrop(
      oriented,
      x: left,
      y: top,
      width: width,
      height: height,
    );

    final tempDir = await getTemporaryDirectory();
    final portraitPath =
        '${tempDir.path}/document_portrait_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(portraitPath).writeAsBytes(
      img.encodeJpg(portraitRegion, quality: 92),
    );

    final faceCrop = await SingleFaceCropper.cropFromImageFileWithCustomError(
      path: portraitPath,
      noFaceMessage: 'No usable face detected in the document portrait region.',
      multipleFacesMessage:
          'Multiple faces detected in the document portrait region.',
      paddingFactor: 0.0,
    );

    return DocumentPortraitCropResult(
      portraitPath: portraitPath,
      croppedFace: faceCrop.croppedFace,
    );
  }
}
