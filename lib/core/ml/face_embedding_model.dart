import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../vision/single_face_cropper.dart';
import 'face_embedding_contract.dart';
import 'model_loader.dart';
import 'model_contract_types.dart';

class FaceEmbeddingPrediction {
  const FaceEmbeddingPrediction({
    required this.embedding,
    required this.latencyMs,
    required this.threshold,
  });

  final List<double> embedding;
  final double latencyMs;
  final double threshold;
}

class FaceEmbeddingComparison {
  const FaceEmbeddingComparison({
    required this.score,
    required this.threshold,
    required this.passedThreshold,
    required this.firstLatencyMs,
    required this.secondLatencyMs,
  });

  final double score;
  final double threshold;
  final bool passedThreshold;
  final double firstLatencyMs;
  final double secondLatencyMs;
}

class FaceEmbeddingModel {
  /// Runs the optional mobile face embedding model for thesis benchmarking.
  ///
  /// This is kept separate from the backend match decision until the document
  /// portrait crop path and acceptance policy are finalized.
  static Future<FaceEmbeddingPrediction?> predictFromFile(
    String path,
  ) async {
    final cropResult = await SingleFaceCropper.cropFromFile(path);
    return predictFromImage(cropResult.croppedFace);
  }

  static Future<FaceEmbeddingPrediction?> predictFromImage(
    img.Image image,
  ) async {
    final interpreter = await ModelLoader.loadOptionalFaceEmbedding();
    if (interpreter == null) return null;

    final contract = await FaceEmbeddingContract.load();
    contract.validateInterpreter(interpreter);

    final resized = img.copyResize(
      image,
      width: contract.inputWidth,
      height: contract.inputHeight,
    );
    final input = _imageToTensor(resized, contract: contract);
    final output = _createOutputBuffer(contract.outputShape);
    final stopwatch = Stopwatch()..start();
    interpreter.run(input, output);
    stopwatch.stop();

    final embedding = _normalizeIfRequired(
      _flattenOutput(output),
      l2Normalize: contract.l2NormalizeEmbedding,
    );
    return FaceEmbeddingPrediction(
      embedding: embedding,
      latencyMs: stopwatch.elapsedMicroseconds / 1000,
      threshold: contract.threshold,
    );
  }

  static Future<FaceEmbeddingComparison?> compareFiles({
    required String firstPath,
    required String secondPath,
  }) async {
    final first = await predictFromFile(firstPath);
    final second = await predictFromFile(secondPath);
    if (first == null || second == null) return null;

    final score = similarityFromEmbeddings(
      first.embedding,
      second.embedding,
    );
    final threshold = first.threshold;
    return FaceEmbeddingComparison(
      score: score,
      threshold: threshold,
      passedThreshold: score >= threshold,
      firstLatencyMs: first.latencyMs,
      secondLatencyMs: second.latencyMs,
    );
  }

  static double similarityFromEmbeddings(
    List<double> first,
    List<double> second,
  ) {
    if (first.length != second.length || first.isEmpty) {
      throw StateError(
        'Face embedding similarity requires equal non-empty vectors.',
      );
    }

    double dot = 0;
    double firstNorm = 0;
    double secondNorm = 0;
    for (var i = 0; i < first.length; i++) {
      dot += first[i] * second[i];
      firstNorm += first[i] * first[i];
      secondNorm += second[i] * second[i];
    }

    if (firstNorm == 0 || secondNorm == 0) {
      throw StateError('Face embedding similarity cannot use zero vectors.');
    }

    final cosine = dot / (math.sqrt(firstNorm) * math.sqrt(secondNorm));
    return (cosine + 1) / 2;
  }

  static Object _imageToTensor(
    img.Image image, {
    required FaceEmbeddingContract contract,
  }) {
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

  static Object _createOutputBuffer(List<int> shape) {
    if (shape.isEmpty) {
      throw StateError('Face embedding output shape cannot be empty.');
    }
    if (shape.length == 1) {
      return List<double>.filled(shape[0], 0.0);
    }
    return List.generate(
        shape[0], (_) => _createOutputBuffer(shape.sublist(1)));
  }

  static List<double> _flattenOutput(Object output) {
    final result = <double>[];
    void walk(Object? node) {
      if (node is num) {
        result.add(node.toDouble());
      } else if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    walk(output);
    if (result.isEmpty) {
      throw StateError('Unsupported face embedding output.');
    }
    return result;
  }

  static List<double> _normalizeIfRequired(
    List<double> embedding, {
    required bool l2Normalize,
  }) {
    if (!l2Normalize) return embedding;
    final norm = math.sqrt(
      embedding.fold<double>(0.0, (sum, value) => sum + (value * value)),
    );
    if (norm == 0) {
      throw StateError('Face embedding vector cannot be zero.');
    }
    return embedding.map((value) => value / norm).toList(growable: false);
  }
}
