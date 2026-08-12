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
    contract.validateInterpreter(interpreter);

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
    final output = _createOutputBuffer(contract.outputShape);
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

  static Object _imageToTensor(
    img.Image image, {
    required LivenessShadowContract contract,
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

    if (contract.layout.name == 'nchw') {
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
      throw StateError('Liveness shadow output shape cannot be empty.');
    }
    if (shape.length == 1) {
      return List<double>.filled(shape[0], 0.0);
    }
    return List.generate(
      shape[0],
      (_) => _createOutputBuffer(shape.sublist(1)),
    );
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
      throw StateError('Unsupported liveness shadow output.');
    }
    return result;
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
