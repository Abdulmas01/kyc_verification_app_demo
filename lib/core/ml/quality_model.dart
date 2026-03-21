import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'model_loader.dart';

enum DocumentQuality { good, blurry, glare, dark, noDocument }

class QualityResult {
  final DocumentQuality quality;
  final double confidence;
  final List<double> probabilities;

  const QualityResult({
    required this.quality,
    required this.confidence,
    required this.probabilities,
  });

  bool get isGood => quality == DocumentQuality.good && confidence >= 0.7;

  String get message {
    switch (quality) {
      case DocumentQuality.good:
        return 'Hold steady...';
      case DocumentQuality.blurry:
        return 'Hold the phone still';
      case DocumentQuality.glare:
        return 'Reduce glare and adjust angle';
      case DocumentQuality.dark:
        return 'Move to a brighter area';
      case DocumentQuality.noDocument:
        return 'Position your ID in the frame';
    }
  }
}

class QualityModel {
  static const List<String> _labels = [
    'GOOD',
    'BLURRY',
    'GLARE',
    'DARK',
    'NO_DOCUMENT',
  ];

  static Future<QualityResult> predictFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Unable to decode image');
    }

    return predictFromImage(image);
  }

  static Future<QualityResult> predictFromImage(img.Image image) async {
    final resized = img.copyResize(image, width: 224, height: 224);
    final input = _imageToTensor(resized);
    final output = List.generate(1, (_) => List.filled(5, 0.0));

    final Interpreter model = ModelLoader.docQuality;
    model.run(input, output);

    final probs = output.first.map((e) => e.toDouble()).toList();
    final maxIdx = _argMax(probs);

    return QualityResult(
      quality: _toQuality(_labels[maxIdx]),
      confidence: probs[maxIdx],
      probabilities: probs,
    );
  }

  static DocumentQuality _toQuality(String label) {
    switch (label) {
      case 'GOOD':
        return DocumentQuality.good;
      case 'BLURRY':
        return DocumentQuality.blurry;
      case 'GLARE':
        return DocumentQuality.glare;
      case 'DARK':
        return DocumentQuality.dark;
      case 'NO_DOCUMENT':
      default:
        return DocumentQuality.noDocument;
    }
  }

  static int _argMax(List<double> values) {
    var maxIndex = 0;
    var maxValue = values.first;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  static List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    return [
      List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        }),
      ),
    ];
  }
}
