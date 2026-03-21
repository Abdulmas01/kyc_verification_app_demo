import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  static Future<File> normalizeDocumentImage({
    required String inputPath,
    Rect? boundingBox,
    List<Offset>? corners,
    int outputWidth = 856,
    int outputHeight = 540,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unable to decode image');
    }

    // Normalize orientation if EXIF data exists.
    final oriented = img.bakeOrientation(decoded);

    img.Image cropped = oriented;
    Rect? cropRect = boundingBox;
    if (corners != null && corners.length == 4) {
      final left = corners.map((p) => p.dx).reduce(min);
      final top = corners.map((p) => p.dy).reduce(min);
      final right = corners.map((p) => p.dx).reduce(max);
      final bottom = corners.map((p) => p.dy).reduce(max);
      cropRect = Rect.fromLTRB(left, top, right, bottom);
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
}
