import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/app_assets.dart';
import 'model_contract_exception.dart';
import 'model_contract_types.dart';

class DocumentQualityContract {
  const DocumentQualityContract({
    required this.classes,
    required this.inputWidth,
    required this.inputHeight,
    required this.inputChannels,
    required this.layout,
    required this.normalization,
    required this.inputShape,
    this.sourceRunId,
    this.sha256,
    this.artifact,
  });

  final List<String> classes;
  final int inputWidth;
  final int inputHeight;
  final int inputChannels;
  final ModelTensorLayout layout;
  final ModelNormalization normalization;
  final List<int> inputShape;
  final String? sourceRunId;
  final String? sha256;
  final String? artifact;

  static const developmentFallback = DocumentQualityContract(
    classes: ['GOOD', 'BLURRY', 'GLARE', 'DARK', 'NO_DOCUMENT'],
    inputWidth: 224,
    inputHeight: 224,
    inputChannels: 3,
    layout: ModelTensorLayout.nchw,
    normalization: ModelNormalization(
      scale: 1 / 255,
      mean: [0.485, 0.456, 0.406],
      std: [0.229, 0.224, 0.225],
    ),
    inputShape: [1, 3, 224, 224],
  );

  static Future<DocumentQualityContract> load({
    bool allowDevelopmentFallback = false,
  }) async {
    try {
      final jsonString =
          await rootBundle.loadString(AppAssets.docQualityContract);
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const ModelContractException(
          'Document quality contract root must be a JSON object.',
        );
      }
      return DocumentQualityContract.fromJson(decoded);
    } catch (error) {
      if (kDebugMode && allowDevelopmentFallback) {
        return developmentFallback;
      }
      if (error is ModelContractException) rethrow;
      throw ModelContractException(
        'Failed to load document quality contract: $error',
      );
    }
  }

  factory DocumentQualityContract.fromJson(Map<String, dynamic> json) {
    final inputMap = _requireMap(json, 'input');
    final outputMap = _requireMap(json, 'output');
    final classes = _requireStringList(
      outputMap['classes'] ?? json['classes'],
      fieldName: 'classes',
    );
    if (classes.isEmpty) {
      throw const ModelContractException(
        'Document quality contract classes must not be empty.',
      );
    }

    final inputShape =
        _requireIntShape(inputMap['shape'], fieldName: 'input.shape');
    if (inputShape.length != 4) {
      throw ModelContractException(
        'Document quality input.shape must have 4 dimensions, got ${inputShape.length}.',
      );
    }

    final layout = _parseLayout(inputMap['layout'], fieldName: 'input.layout');
    final channels =
        layout == ModelTensorLayout.nchw ? inputShape[1] : inputShape[3];
    if (channels != 3) {
      throw ModelContractException(
        'Document quality contract requires 3 input channels, got $channels.',
      );
    }

    final dtype = _requireString(inputMap['dtype'], fieldName: 'input.dtype');
    if (dtype != 'float32') {
      throw ModelContractException(
        'Unsupported document quality input dtype "$dtype"; expected float32.',
      );
    }

    return DocumentQualityContract(
      classes: classes,
      inputWidth:
          layout == ModelTensorLayout.nchw ? inputShape[3] : inputShape[2],
      inputHeight:
          layout == ModelTensorLayout.nchw ? inputShape[2] : inputShape[1],
      inputChannels: channels,
      layout: layout,
      normalization: _parseNormalization(
        inputMap['normalization'],
        fieldName: 'input.normalization',
      ),
      inputShape: inputShape,
      sourceRunId: json['source_run_id']?.toString(),
      sha256: json['sha256']?.toString(),
      artifact: json['artifact']?.toString(),
    );
  }

  void validateInterpreter(Interpreter interpreter) {
    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);

    if (inputTensor.type != TensorType.float32) {
      throw ModelContractException(
        'Document quality runtime input dtype is ${inputTensor.type}, expected float32.',
      );
    }

    if (!listEquals(inputTensor.shape, inputShape)) {
      throw ModelContractException(
        'Document quality runtime input shape ${inputTensor.shape} does not match contract $inputShape.',
      );
    }

    final outputShape = outputTensor.shape;
    if (outputShape.length != 2 ||
        outputShape[0] != 1 ||
        outputShape[1] != classes.length) {
      throw ModelContractException(
        'Document quality runtime output shape $outputShape does not match expected [1, ${classes.length}].',
      );
    }
  }

  static Map<String, dynamic> _requireMap(
      Map<String, dynamic> json, String fieldName) {
    final value = json[fieldName];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw ModelContractException('$fieldName must be a JSON object.');
  }

  static String _requireString(Object? value, {required String fieldName}) {
    final stringValue = value?.toString();
    if (stringValue == null || stringValue.isEmpty) {
      throw ModelContractException('$fieldName must be a non-empty string.');
    }
    return stringValue;
  }

  static List<String> _requireStringList(Object? value,
      {required String fieldName}) {
    if (value is! List) {
      throw ModelContractException('$fieldName must be a string array.');
    }
    final result = value.map((item) => item.toString()).toList(growable: false);
    if (result.any((item) => item.isEmpty)) {
      throw ModelContractException('$fieldName cannot contain empty values.');
    }
    return result;
  }

  static List<int> _requireIntShape(Object? value,
      {required String fieldName}) {
    if (value is! List) {
      throw ModelContractException('$fieldName must be an array.');
    }
    return value.map((item) {
      if (item is int) return item;
      if (item is num) return item.toInt();
      if (item is String && (item == 'N' || item == 'n')) return 1;
      final parsed = int.tryParse(item.toString());
      if (parsed == null) {
        throw ModelContractException(
            '$fieldName contains a non-numeric value: $item.');
      }
      return parsed;
    }).toList(growable: false);
  }

  static ModelTensorLayout _parseLayout(Object? value,
      {required String fieldName}) {
    final layout = _requireString(value, fieldName: fieldName).toUpperCase();
    switch (layout) {
      case 'NCHW':
        return ModelTensorLayout.nchw;
      case 'NHWC':
        return ModelTensorLayout.nhwc;
      default:
        throw ModelContractException(
          '$fieldName must be NCHW or NHWC, got "$layout".',
        );
    }
  }

  static ModelNormalization _parseNormalization(
    Object? value, {
    required String fieldName,
  }) {
    if (value is! Map) {
      throw ModelContractException(
          '$fieldName must be an object with scale, mean, and std.');
    }
    final map = Map<String, dynamic>.from(value);
    final mean = _requireDoubleList(map['mean'], fieldName: '$fieldName.mean');
    final std = _requireDoubleList(map['std'], fieldName: '$fieldName.std');
    if (mean.length != 3 || std.length != 3) {
      throw ModelContractException(
          '$fieldName mean/std must each contain 3 values.');
    }
    if (std.any((value) => value == 0)) {
      throw ModelContractException('$fieldName.std cannot contain zero.');
    }
    return ModelNormalization(
      scale: _requireDouble(map['scale'], fieldName: '$fieldName.scale'),
      mean: mean,
      std: std,
    );
  }

  static double _requireDouble(Object? value, {required String fieldName}) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw ModelContractException('$fieldName must be numeric.');
    }
    return parsed;
  }

  static List<double> _requireDoubleList(Object? value,
      {required String fieldName}) {
    if (value is! List) {
      throw ModelContractException('$fieldName must be a numeric array.');
    }
    return value
        .map((item) => _requireDouble(item, fieldName: fieldName))
        .toList(growable: false);
  }
}
