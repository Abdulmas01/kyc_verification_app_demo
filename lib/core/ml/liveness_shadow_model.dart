import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'model_loader.dart';

class LivenessShadowPrediction {
  const LivenessShadowPrediction({
    required this.liveScore,
    required this.latencyMs,
  });

  final double liveScore;
  final double latencyMs;
}

class LivenessShadowModel {
  /// Runs the optional mobile liveness model for shadow benchmarking only.
  ///
  /// This does not participate in the authoritative decision path. Backend ONNX
  /// inference remains the trusted source of `liveness_score`.
  static Future<LivenessShadowPrediction?> predictFromFile(String path) async {
    final interpreter = await ModelLoader.loadOptionalLivenessShadow();
    if (interpreter == null) return null;

    final bytes = await File(path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Unable to decode selfie image for liveness shadow.');
    }

    final resized = img.copyResize(image, width: 128, height: 128);
    final input = _imageToTensor(resized);
    final output = _createOutputBuffer(interpreter.getOutputTensor(0).shape);
    final stopwatch = Stopwatch()..start();
    interpreter.run(input, output);
    stopwatch.stop();

    final values = _flattenOutput(output);
    return LivenessShadowPrediction(
      liveScore: _extractLiveScore(values),
      latencyMs: stopwatch.elapsedMicroseconds / 1000,
    );
  }

  static List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    return [
      List.generate(
        128,
        (y) => List.generate(128, (x) {
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

  static Object _createOutputBuffer(List<int> shape) {
    final width = shape.isNotEmpty ? shape.last : 1;
    return List.generate(1, (_) => List.filled(width, 0.0));
  }

  static List<double> _flattenOutput(Object output) {
    if (output is List && output.isNotEmpty && output.first is List) {
      final row = output.first as List;
      return row.map((value) => (value as num).toDouble()).toList();
    }
    throw StateError('Unsupported liveness shadow output.');
  }

  static double _extractLiveScore(List<double> values) {
    if (values.isEmpty) {
      throw StateError('Liveness shadow model returned no values.');
    }
    if (values.length == 1) {
      return 1 / (1 + math.exp(-values.first));
    }
    final maxVal = values.reduce(math.max);
    final expVals = values.map((v) => math.exp(v - maxVal)).toList();
    final sum = expVals.fold<double>(0.0, (acc, v) => acc + v);
    return expVals[1] / sum;
  }
}
