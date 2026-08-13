import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'document_quality_contract.dart';
import 'model_loader.dart';
import 'model_contract_types.dart';

enum DocumentQuality { good, blurry, glare, dark, noDocument }

class QualityResult {
  final DocumentQuality quality;
  final DocumentQuality guidanceQuality;
  final double confidence;
  final List<double> probabilities;
  final List<String> labels;

  const QualityResult({
    required this.quality,
    required this.guidanceQuality,
    required this.confidence,
    required this.probabilities,
    required this.labels,
  });

  bool get isGood => quality == DocumentQuality.good && confidence >= 0.7;

  String get message {
    switch (guidanceQuality) {
      case DocumentQuality.good:
        return 'Hold steady for capture.';
      case DocumentQuality.blurry:
        return 'Hold still for a clearer capture.';
      case DocumentQuality.glare:
        return 'Tilt slightly to reduce glare.';
      case DocumentQuality.dark:
        return 'Move to better lighting.';
      case DocumentQuality.noDocument:
        return 'Place your ID fully inside the frame.';
    }
  }

  double probabilityForLabel(String label) {
    final index = labels.indexOf(label);
    if (index == -1 || index >= probabilities.length) return 0;
    return probabilities[index];
  }

  String topPredictionsSummary({int limit = 3}) {
    final entries = <MapEntry<String, double>>[];
    for (var i = 0; i < labels.length && i < probabilities.length; i++) {
      entries.add(MapEntry(labels[i], probabilities[i]));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(limit)
        .map((entry) =>
            '${entry.key}:${(entry.value * 100).toStringAsFixed(1)}%')
        .join(', ');
  }
}

class QualityModel {
  static Future<QualityResult> predictFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Unable to decode image');
    }

    return predictFromImage(image);
  }

  static Future<QualityResult> predictFromImage(img.Image image) async {
    final contract = await DocumentQualityContract.load();
    final resized = img.copyResize(
      image,
      width: contract.inputWidth,
      height: contract.inputHeight,
    );
    final input = _imageToTensor(resized, contract);
    final output = List.generate(
      1,
      (_) => List.filled(contract.classes.length, 0.0),
    );

    final Interpreter model = ModelLoader.docQuality;
    contract.validateInterpreter(model);
    model.run(input, output);

    final probs = output.first.map((e) => e.toDouble()).toList();
    return fromProbabilities(probs, labels: contract.classes);
  }

  static QualityResult fromProbabilities(
    List<double> probs, {
    List<String>? labels,
  }) {
    final normalized = _softmax(probs);
    final maxIdx = _argMax(normalized);
    final activeLabels =
        labels ?? DocumentQualityContract.developmentFallback.classes;
    final safeLabel = maxIdx < activeLabels.length
        ? activeLabels[maxIdx]
        : DocumentQualityContract.developmentFallback.classes[maxIdx];
    final predictedQuality = _toQuality(safeLabel);
    return QualityResult(
      quality: predictedQuality,
      guidanceQuality: _resolveGuidanceQuality(
        predictedQuality: predictedQuality,
        probabilities: normalized,
        labels: activeLabels,
      ),
      confidence: normalized[maxIdx],
      probabilities: normalized,
      labels: activeLabels,
    );
  }

// TODO : review this later for bug in logics
  static DocumentQuality _resolveGuidanceQuality({
    required DocumentQuality predictedQuality,
    required List<double> probabilities,
    required List<String> labels,
  }) {
    if (predictedQuality != DocumentQuality.noDocument) {
      return predictedQuality;
    }

    final noDocumentIndex = labels.indexOf('NO_DOCUMENT');
    if (noDocumentIndex == -1 || noDocumentIndex >= probabilities.length) {
      return predictedQuality;
    }

    final noDocumentConfidence = probabilities[noDocumentIndex];
    if (noDocumentConfidence >= 0.60) {
      return predictedQuality;
    }

    var bestAlternativeIndex = -1;
    var bestAlternativeConfidence = -1.0;

    for (var i = 0; i < labels.length && i < probabilities.length; i++) {
      if (i == noDocumentIndex) continue;
      if (probabilities[i] > bestAlternativeConfidence) {
        bestAlternativeConfidence = probabilities[i];
        bestAlternativeIndex = i;
      }
    }

    if (bestAlternativeIndex == -1 || bestAlternativeConfidence < 0.20) {
      return predictedQuality;
    }

    final alternativeQuality = _toQuality(labels[bestAlternativeIndex]);
    return alternativeQuality == DocumentQuality.good
        ? predictedQuality
        : alternativeQuality;
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
    final expVals =
        values.map((v) => math.exp(v - maxVal)).toList(growable: false);
    final sum = expVals.fold<double>(0.0, (acc, v) => acc + v);
    if (sum == 0) return values;
    return expVals.map((v) => v / sum).toList(growable: false);
  }

  static Object _imageToTensor(
    img.Image image,
    DocumentQualityContract contract,
  ) {
    final rgb = List.generate(
      image.height,
      (y) => List.generate(image.width, (x) {
        final pixel = image.getPixel(x, y);
        return [
          ((pixel.r * contract.normalization.scale) -
                  contract.normalization.mean[0]) /
              contract.normalization.std[0],
          ((pixel.g * contract.normalization.scale) -
                  contract.normalization.mean[1]) /
              contract.normalization.std[1],
          ((pixel.b * contract.normalization.scale) -
                  contract.normalization.mean[2]) /
              contract.normalization.std[2],
        ];
      }),
    );

    if (contract.layout == ModelTensorLayout.nchw) {
      return [
        List.generate(
          contract.inputChannels,
          (channel) => List.generate(
            image.height,
            (y) => List.generate(image.width, (x) => rgb[y][x][channel]),
          ),
        ),
      ];
    }

    return [rgb];
  }
}
