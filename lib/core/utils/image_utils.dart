import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  static Future<File> normalizeDocumentImage({
    required String inputPath,
    Rect? boundingBox,
    int outputWidth = 856,
    int outputHeight = 540,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unable to decode image');
    }

    img.Image cropped = decoded;
    if (boundingBox != null) {
      final left = max(0, boundingBox.left.floor());
      final top = max(0, boundingBox.top.floor());
      final right = min(decoded.width, boundingBox.right.ceil());
      final bottom = min(decoded.height, boundingBox.bottom.ceil());

      final width = max(1, right - left);
      final height = max(1, bottom - top);

      cropped = img.copyCrop(
        decoded,
        x: left,
        y: top,
        width: width,
        height: height,
      );
    }

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
