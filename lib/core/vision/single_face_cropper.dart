import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class SingleFaceCropResult {
  const SingleFaceCropResult({
    required this.croppedFace,
    required this.faceCount,
  });

  final img.Image croppedFace;
  final int faceCount;
}

class SingleFaceCropper {
  /// Detects and crops one usable face from a captured selfie.
  ///
  /// This mirrors the backend policy for liveness and face matching:
  /// exactly one usable face is required. Zero or multiple detections are
  /// rejected so mobile shadow benchmarking does not silently diverge from
  /// backend preprocessing.
  static Future<SingleFaceCropResult> cropFromFile(
    String path, {
    double paddingFactor = 0.20,
  }) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: false,
        enableTracking: false,
        enableClassification: false,
      ),
    );

    try {
      final faces = await detector.processImage(InputImage.fromFilePath(path));
      if (faces.isEmpty) {
        throw StateError('No usable face detected for shadow liveness.');
      }
      if (faces.length > 1) {
        throw StateError(
          'Multiple faces detected for shadow liveness. Exactly one face is required.',
        );
      }

      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw StateError('Unable to decode selfie image for face cropping.');
      }
      final oriented = img.bakeOrientation(decoded);
      final face = faces.first;
      final crop = _expandAndClamp(
        left: face.boundingBox.left,
        top: face.boundingBox.top,
        right: face.boundingBox.right,
        bottom: face.boundingBox.bottom,
        imageWidth: oriented.width,
        imageHeight: oriented.height,
        paddingFactor: paddingFactor,
      );

      final cropped = img.copyCrop(
        oriented,
        x: crop.$1,
        y: crop.$2,
        width: crop.$3,
        height: crop.$4,
      );

      return SingleFaceCropResult(
        croppedFace: cropped,
        faceCount: 1,
      );
    } finally {
      detector.close();
    }
  }

  static Future<SingleFaceCropResult> cropFromImageFileWithCustomError({
    required String path,
    required String noFaceMessage,
    required String multipleFacesMessage,
    double paddingFactor = 0.20,
  }) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: false,
        enableTracking: false,
        enableClassification: false,
      ),
    );

    try {
      final faces = await detector.processImage(InputImage.fromFilePath(path));
      if (faces.isEmpty) {
        throw StateError(noFaceMessage);
      }
      if (faces.length > 1) {
        throw StateError(multipleFacesMessage);
      }

      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw StateError('Unable to decode image for face cropping.');
      }
      final oriented = img.bakeOrientation(decoded);
      final face = faces.first;
      final crop = _expandAndClamp(
        left: face.boundingBox.left,
        top: face.boundingBox.top,
        right: face.boundingBox.right,
        bottom: face.boundingBox.bottom,
        imageWidth: oriented.width,
        imageHeight: oriented.height,
        paddingFactor: paddingFactor,
      );

      final cropped = img.copyCrop(
        oriented,
        x: crop.$1,
        y: crop.$2,
        width: crop.$3,
        height: crop.$4,
      );

      return SingleFaceCropResult(
        croppedFace: cropped,
        faceCount: 1,
      );
    } finally {
      detector.close();
    }
  }

  static (int, int, int, int) _expandAndClamp({
    required double left,
    required double top,
    required double right,
    required double bottom,
    required int imageWidth,
    required int imageHeight,
    required double paddingFactor,
  }) {
    final width = right - left;
    final height = bottom - top;
    final padX = width * paddingFactor;
    final padY = height * paddingFactor;

    final clampedLeft = math.max(0, (left - padX).floor());
    final clampedTop = math.max(0, (top - padY).floor());
    final clampedRight = math.min(imageWidth, (right + padX).ceil());
    final clampedBottom = math.min(imageHeight, (bottom + padY).ceil());

    return (
      clampedLeft,
      clampedTop,
      math.max(1, clampedRight - clampedLeft),
      math.max(1, clampedBottom - clampedTop),
    );
  }
}
