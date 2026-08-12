import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/app_assets.dart';
import 'model_contract_exception.dart';
import 'model_contract_types.dart';

class LivenessShadowContract {
  const LivenessShadowContract({
    required this.inputWidth,
    required this.inputHeight,
    required this.inputChannels,
    required this.layout,
    required this.normalization,
    required this.inputShape,
    required this.outputShape,
    required this.faceCropRequired,
    required this.faceCropMargin,
    required this.multipleFacesPolicy,
    required this.outputRepresentation,
    required this.liveClassIndex,
    required this.threshold,
    this.sourceRunId,
  });

  final int inputWidth;
  final int inputHeight;
  final int inputChannels;
  final ModelTensorLayout layout;
  final ModelNormalization normalization;
  final List<int> inputShape;
  final List<int> outputShape;
  final bool faceCropRequired;
  final double faceCropMargin;
  final String multipleFacesPolicy;
  final String outputRepresentation;
  final int liveClassIndex;
  final double threshold;
  final String? sourceRunId;

  static const developmentFallback = LivenessShadowContract(
    inputWidth: 128,
    inputHeight: 128,
    inputChannels: 3,
    layout: ModelTensorLayout.nhwc,
    normalization: ModelNormalization(
      scale: 1 / 255,
      mean: [0.485, 0.456, 0.406],
      std: [0.229, 0.224, 0.225],
    ),
    inputShape: [1, 128, 128, 3],
    outputShape: [1, 1],
    faceCropRequired: true,
    faceCropMargin: 0.0,
    multipleFacesPolicy: 'reject',
    outputRepresentation: 'logit',
    liveClassIndex: 1,
    threshold: 0.5,
  );

  static Future<LivenessShadowContract> load({
    bool allowDevelopmentFallback = false,
  }) async {
    try {
      final jsonString =
          await rootBundle.loadString(AppAssets.livenessShadowContract);
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const ModelContractException(
          'Liveness shadow contract root must be a JSON object.',
        );
      }
      return LivenessShadowContract.fromJson(decoded);
    } catch (error) {
      if (kDebugMode && allowDevelopmentFallback) {
        return developmentFallback;
      }
      if (error is ModelContractException) rethrow;
      throw ModelContractException(
        'Failed to load liveness shadow contract: $error',
      );
    }
  }

  factory LivenessShadowContract.fromJson(Map<String, dynamic> json) {
    final inputMap = _requireMap(json, 'input');
    final outputMap = _requireMap(json, 'output');
    final faceCropMap = _requireMap(json, 'face_crop');

    final inputShape =
        _requireIntShape(inputMap['shape'], fieldName: 'input.shape');
    if (inputShape.length != 4) {
      throw ModelContractException(
        'Liveness input.shape must have 4 dimensions, got ${inputShape.length}.',
      );
    }

    final outputShape =
        _requireIntShape(outputMap['shape'], fieldName: 'output.shape');
    if (outputShape.isEmpty) {
      throw const ModelContractException(
          'Liveness output.shape must not be empty.');
    }

    final layout = _parseLayout(inputMap['layout'], fieldName: 'input.layout');
    final channels =
        layout == ModelTensorLayout.nchw ? inputShape[1] : inputShape[3];
    if (channels != 3) {
      throw ModelContractException(
        'Liveness contract requires 3 input channels, got $channels.',
      );
    }

    final dtype = _requireString(inputMap['dtype'], fieldName: 'input.dtype');
    if (dtype != 'float32') {
      throw ModelContractException(
        'Unsupported liveness input dtype "$dtype"; expected float32.',
      );
    }

    final faceCropRequired = _requireBool(
      faceCropMap['required'],
      fieldName: 'face_crop.required',
    );
    if (!faceCropRequired) {
      throw const ModelContractException(
        'Liveness contract must require face cropping.',
      );
    }

    final multipleFacesPolicy = _requireString(
      faceCropMap['multiple_faces'],
      fieldName: 'face_crop.multiple_faces',
    );
    if (multipleFacesPolicy != 'reject') {
      throw ModelContractException(
        'Unsupported liveness multiple_faces policy "$multipleFacesPolicy".',
      );
    }

    final outputRepresentation = _requireString(
      outputMap['representation'],
      fieldName: 'output.representation',
    );
    if (outputRepresentation != 'logit') {
      throw ModelContractException(
        'Unsupported liveness output representation "$outputRepresentation".',
      );
    }

    final thresholdDomain = _requireString(
      json['threshold_domain'],
      fieldName: 'threshold_domain',
    );
    if (thresholdDomain != 'post_sigmoid_live_probability') {
      throw ModelContractException(
        'Unsupported liveness threshold_domain "$thresholdDomain".',
      );
    }

    return LivenessShadowContract(
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
      outputShape: outputShape,
      faceCropRequired: faceCropRequired,
      faceCropMargin: _requireDouble(
        faceCropMap['margin'],
        fieldName: 'face_crop.margin',
      ),
      multipleFacesPolicy: multipleFacesPolicy,
      outputRepresentation: outputRepresentation,
      liveClassIndex:
          _requireInt(outputMap['live_class'], fieldName: 'output.live_class'),
      threshold: _requireDouble(json['threshold'], fieldName: 'threshold'),
      sourceRunId: json['source_run_id']?.toString(),
    );
  }

  void validateInterpreter(Interpreter interpreter) {
    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);

    if (inputTensor.type != TensorType.float32) {
      throw ModelContractException(
        'Liveness runtime input dtype is ${inputTensor.type}, expected float32.',
      );
    }

    if (!listEquals(inputTensor.shape, inputShape)) {
      throw ModelContractException(
        'Liveness runtime input shape ${inputTensor.shape} does not match contract $inputShape.',
      );
    }

    if (!listEquals(outputTensor.shape, outputShape)) {
      throw ModelContractException(
        'Liveness runtime output shape ${outputTensor.shape} does not match contract $outputShape.',
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

  static bool _requireBool(Object? value, {required String fieldName}) {
    if (value is bool) return value;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    throw ModelContractException('$fieldName must be a boolean.');
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

  static int _requireInt(Object? value, {required String fieldName}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw ModelContractException('$fieldName must be an integer.');
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
