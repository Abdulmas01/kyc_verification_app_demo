import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../vision/single_face_cropper.dart';
import 'liveness_shadow_contract.dart';
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

    final contract = await LivenessShadowContract.load();
    if (contract.multipleFacesPolicy != 'reject') {
      throw StateError(
        'Unsupported liveness shadow multiple_faces policy: ${contract.multipleFacesPolicy}',
      );
    }
    final cropResult = await SingleFaceCropper.cropFromFile(
      path,
      paddingFactor: contract.faceCropMargin,
    );
    final resized = img.copyResize(
      cropResult.croppedFace,
      width: contract.inputWidth,
      height: contract.inputHeight,
    );
    final input = _imageToTensor(
      resized,
      contract: contract,
    );
    final output = _createOutputBuffer(interpreter.getOutputTensor(0).shape);
    final stopwatch = Stopwatch()..start();
    interpreter.run(input, output);
    stopwatch.stop();

    final values = _flattenOutput(output);
    return LivenessShadowPrediction(
      liveScore: _extractLiveScore(
        values,
        liveClassIndex: contract.liveClassIndex,
      ),
      latencyMs: stopwatch.elapsedMicroseconds / 1000,
    );
  }

  static List<List<List<List<double>>>> _imageToTensor(
    img.Image image, {
    required LivenessShadowContract contract,
  }) {
    return [
      List.generate(
        image.height,
        (y) => List.generate(image.width, (x) {
          final pixel = image.getPixel(x, y);
          final rgb = [
            pixel.r * contract.inputScale,
            pixel.g * contract.inputScale,
            pixel.b * contract.inputScale,
          ];
          return [
            (rgb[0] - contract.inputMean[0]) / contract.inputStd[0],
            (rgb[1] - contract.inputMean[1]) / contract.inputStd[1],
            (rgb[2] - contract.inputMean[2]) / contract.inputStd[2],
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

  static double _extractLiveScore(
    List<double> values, {
    required int liveClassIndex,
  }) {
    if (values.isEmpty) {
      throw StateError('Liveness shadow model returned no values.');
    }
    if (values.length == 1) {
      return 1 / (1 + math.exp(-values.first));
    }
    final maxVal = values.reduce(math.max);
    final expVals = values.map((v) => math.exp(v - maxVal)).toList();
    final sum = expVals.fold<double>(0.0, (acc, v) => acc + v);
    if (liveClassIndex < 0 || liveClassIndex >= expVals.length) {
      throw StateError('Invalid live class index for liveness shadow model.');
    }
    return expVals[liveClassIndex] / sum;
  }
}
