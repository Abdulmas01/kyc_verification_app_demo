import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  static const double documentGuideWidthFactor = 0.86;
  static const double documentGuideAspectRatio = 0.63;
  static const double documentGuideMaxHeightFactor = 0.82;
  static const double documentQualityCropScale = 0.82;

  static Future<File> normalizeDocumentImage({
    required String inputPath,
    Rect? boundingBox,
    List<Offset>? corners,
    int outputWidth = 856,
    int outputHeight = 540,
    bool fallbackToCenteredGuideCrop = false,
    bool lockCropToGuideFrame = false,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unable to decode image');
    }

    // Normalize orientation if EXIF data exists.
    final oriented = img.bakeOrientation(decoded);
    final guideRect = centeredGuideCropRect(
      imageWidth: oriented.width.toDouble(),
      imageHeight: oriented.height.toDouble(),
    );

    img.Image cropped = oriented;
    Rect? cropRect = boundingBox;
    if (corners != null && corners.length == 4) {
      final left = corners.map((p) => p.dx).reduce(min);
      final top = corners.map((p) => p.dy).reduce(min);
      final right = corners.map((p) => p.dx).reduce(max);
      final bottom = corners.map((p) => p.dy).reduce(max);
      cropRect = Rect.fromLTRB(left, top, right, bottom);
    }

    if (cropRect == null && fallbackToCenteredGuideCrop) {
      cropRect = guideRect;
    }

    if (cropRect != null && lockCropToGuideFrame) {
      cropRect = _clampRectToGuide(cropRect, guideRect) ?? guideRect;
    }

    if (cropRect != null) {
      final left = max(0, cropRect.left.floor());
      final top = max(0, cropRect.top.floor());
      final right = min(oriented.width, cropRect.right.ceil());
      final bottom = min(oriented.height, cropRect.bottom.ceil());

      final width = max(1, right - left);
      final height = max(1, bottom - top);

      cropped = img.copyCrop(
        oriented,
        x: left,
        y: top,
        width: width,
        height: height,
      );
    }

    // NOTE: This is a crop + resize normalization. If you have true corner
    // points, plug in a perspective transform here.
    final resized = img.copyResize(
      cropped,
      width: outputWidth,
      height: outputHeight,
      interpolation: img.Interpolation.linear,
    );

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/normalized_doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodeJpg(resized, quality: 90));
    return outputFile;
  }

  static Rect centeredGuideCropRect({
    required double imageWidth,
    required double imageHeight,
    double scale = 1.0,
  }) {
    var guideWidth = imageWidth * documentGuideWidthFactor;
    var guideHeight = guideWidth * documentGuideAspectRatio;

    if (guideHeight > imageHeight * documentGuideMaxHeightFactor) {
      guideHeight = imageHeight * documentGuideMaxHeightFactor;
      guideWidth = guideHeight / documentGuideAspectRatio;
    }

    final scaledWidth = guideWidth * scale.clamp(0.1, 1.0);
    final scaledHeight = guideHeight * scale.clamp(0.1, 1.0);

    final left = (imageWidth - scaledWidth) / 2;
    final top = (imageHeight - scaledHeight) / 2;

    return Rect.fromLTWH(left, top, scaledWidth, scaledHeight);
  }

  static Rect? _clampRectToGuide(Rect cropRect, Rect guideRect) {
    final left = max(cropRect.left, guideRect.left);
    final top = max(cropRect.top, guideRect.top);
    final right = min(cropRect.right, guideRect.right);
    final bottom = min(cropRect.bottom, guideRect.bottom);

    if (right <= left || bottom <= top) {
      return null;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }
}
