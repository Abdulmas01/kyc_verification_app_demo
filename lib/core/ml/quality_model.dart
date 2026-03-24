import 'dart:io';
import 'dart:math' as math;

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
  // IMPORTANT: This order must match the model's exported label order.
  // If it doesn't, the UI will show the wrong guidance (e.g., blur vs dark).
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
    return fromProbabilities(probs);
  }

  static QualityResult fromProbabilities(List<double> probs) {
    final normalized = _softmax(probs);
    final maxIdx = _argMax(normalized);
    return QualityResult(
      quality: _toQuality(_labels[maxIdx]),
      confidence: normalized[maxIdx],
      probabilities: normalized,
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

  static List<double> _softmax(List<double> values) {
    if (values.isEmpty) return values;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final expVals = values
        .map((v) => math.exp(v - maxVal))
        .toList(growable: false);
    final sum = expVals.fold<double>(0.0, (acc, v) => acc + v);
    if (sum == 0) return values;
    return expVals.map((v) => v / sum).toList(growable: false);
  }

  static List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    const mean = [0.485, 0.456, 0.406];
    const std = [0.229, 0.224, 0.225];
    return [
      List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = image.getPixel(x, y);
          return [
            (pixel.r / 255.0 - mean[0]) / std[0],
            (pixel.g / 255.0 - mean[1]) / std[1],
            (pixel.b / 255.0 - mean[2]) / std[2],
          ];
        }),
      ),
    ];
  }
}
