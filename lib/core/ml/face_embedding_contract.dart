import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/app_assets.dart';
import 'model_contract_exception.dart';
import 'model_contract_types.dart';
import '../../features/kyc/domain/enums/document_face_source_type.dart';

class FaceEmbeddingContract {
  const FaceEmbeddingContract({
    required this.inputWidth,
    required this.inputHeight,
    required this.inputChannels,
    required this.layout,
    required this.normalization,
    required this.inputShape,
    required this.outputShape,
    required this.embeddingDimension,
    required this.l2NormalizeEmbedding,
    required this.similarityMetric,
    required this.similarityTransform,
    required this.threshold,
    required this.roiByType,
    this.runId,
    this.artifact,
    this.artifactSha256,
    this.usageDesignation,
  });

  final int inputWidth;
  final int inputHeight;
  final int inputChannels;
  final ModelTensorLayout layout;
  final ModelNormalization normalization;
  final List<int> inputShape;
  final List<int> outputShape;
  final int embeddingDimension;
  final bool l2NormalizeEmbedding;
  final String similarityMetric;
  final String similarityTransform;
  final double threshold;
  final Map<DocumentFaceSourceType, (double, double, double, double)> roiByType;
  final String? runId;
  final String? artifact;
  final String? artifactSha256;
  final String? usageDesignation;

  static const developmentFallback = FaceEmbeddingContract(
    inputWidth: 112,
    inputHeight: 112,
    inputChannels: 3,
    layout: ModelTensorLayout.nhwc,
    normalization: ModelNormalization(
      scale: 1.0,
      mean: [127.5, 127.5, 127.5],
      std: [127.5, 127.5, 127.5],
    ),
    inputShape: [1, 112, 112, 3],
    outputShape: [1, 512],
    embeddingDimension: 512,
    l2NormalizeEmbedding: true,
    similarityMetric: 'cosine',
    similarityTransform: '(cosine+1)/2',
    threshold: 0.6741582155227661,
    roiByType: {
      DocumentFaceSourceType.ninSmart: (0.03, 0.38, 0.15, 0.8),
      DocumentFaceSourceType.voterCard: (0.03, 0.4, 0.12, 0.82),
      DocumentFaceSourceType.driversLicense: (0.02, 0.42, 0.1, 0.85),
      DocumentFaceSourceType.passport: (0.1, 0.6, 0.05, 0.75),
      DocumentFaceSourceType.unknown: (0.0, 1.0, 0.0, 1.0),
    },
  );

  static Future<FaceEmbeddingContract> load({
    bool allowDevelopmentFallback = false,
  }) async {
    try {
      final jsonString =
          await rootBundle.loadString(AppAssets.faceEmbeddingContract);
      return FaceEmbeddingContract.fromJsonString(jsonString);
    } catch (error) {
      if (kDebugMode && allowDevelopmentFallback) {
        return developmentFallback;
      }
      if (error is ModelContractException) rethrow;
      throw ModelContractException(
        'Failed to load face embedding contract: $error',
      );
    }
  }

  factory FaceEmbeddingContract.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const ModelContractException(
        'Face embedding contract root must be a JSON object.',
      );
    }
    return FaceEmbeddingContract.fromJson(decoded);
  }

  factory FaceEmbeddingContract.fromJson(Map<String, dynamic> json) {
    final inputMap = _requireMap(json, 'input');
    final outputMap = _requireMap(json, 'output');
    final extractionMap = _requireMap(json, 'extraction');

    final inputShape =
        _requireIntShape(inputMap['shape'], fieldName: 'input.shape');
    if (inputShape.length != 4) {
      throw ModelContractException(
        'Face embedding input.shape must have 4 dimensions, got ${inputShape.length}.',
      );
    }

    final outputShape =
        _requireIntShape(outputMap['shape'], fieldName: 'output.shape');
    if (outputShape.length != 2) {
      throw ModelContractException(
        'Face embedding output.shape must have 2 dimensions, got ${outputShape.length}.',
      );
    }

    final layout = _parseLayout(inputMap['layout'], fieldName: 'input.layout');
    final channels =
        layout == ModelTensorLayout.nchw ? inputShape[1] : inputShape[3];
    if (channels != 3) {
      throw ModelContractException(
        'Face embedding contract requires 3 input channels, got $channels.',
      );
    }

    final dtype = _requireString(inputMap['dtype'], fieldName: 'input.dtype');
    if (dtype != 'float32') {
      throw ModelContractException(
        'Unsupported face embedding input dtype "$dtype"; expected float32.',
      );
    }

    final embeddingDimension = _requireInt(
      outputMap['dimension'],
      fieldName: 'output.dimension',
    );
    if (outputShape[0] != 1 || outputShape[1] != embeddingDimension) {
      throw ModelContractException(
        'Face embedding output.shape $outputShape does not match expected [1, $embeddingDimension].',
      );
    }

    final similarityMetric = _requireString(
      outputMap['similarity_metric'],
      fieldName: 'output.similarity_metric',
    );
    if (similarityMetric != 'cosine') {
      throw ModelContractException(
        'Unsupported face embedding similarity metric "$similarityMetric".',
      );
    }

    final similarityTransform = _requireString(
      outputMap['similarity_transform'],
      fieldName: 'output.similarity_transform',
    );
    if (similarityTransform != '(cosine+1)/2') {
      throw ModelContractException(
        'Unsupported face embedding similarity transform "$similarityTransform".',
      );
    }

    return FaceEmbeddingContract(
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
      embeddingDimension: embeddingDimension,
      l2NormalizeEmbedding: _requireBool(
        outputMap['l2_normalized_by_consumer'],
        fieldName: 'output.l2_normalized_by_consumer',
      ),
      similarityMetric: similarityMetric,
      similarityTransform: similarityTransform,
      threshold: _requireDouble(json['threshold'], fieldName: 'threshold'),
      roiByType: _parseRoiByType(
        extractionMap,
        fieldName: 'extraction.roi_by_type',
      ),
      runId: json['run_id']?.toString(),
      artifact: json['artifact']?.toString(),
      artifactSha256: json['artifact_sha256']?.toString(),
      usageDesignation: json['usage_designation']?.toString(),
    );
  }

  void validateInterpreter(Interpreter interpreter) {
    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);

    if (inputTensor.type != TensorType.float32) {
      throw ModelContractException(
        'Face embedding runtime input dtype is ${inputTensor.type}, expected float32.',
      );
    }

    if (!listEquals(inputTensor.shape, inputShape)) {
      throw ModelContractException(
        'Face embedding runtime input shape ${inputTensor.shape} does not match contract $inputShape.',
      );
    }

    if (!listEquals(outputTensor.shape, outputShape)) {
      throw ModelContractException(
        'Face embedding runtime output shape ${outputTensor.shape} does not match contract $outputShape.',
      );
    }
  }

  (double, double, double, double) portraitRoiFor(
    DocumentFaceSourceType type,
  ) {
    return roiByType[type] ?? roiByType[DocumentFaceSourceType.unknown]!;
  }

  static Map<String, dynamic> _requireMap(
    Map<String, dynamic> json,
    String fieldName,
  ) {
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
          '$fieldName contains a non-numeric value: $item.',
        );
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
        '$fieldName must be an object with scale, mean, and std.',
      );
    }
    final map = Map<String, dynamic>.from(value);
    final mean = _requireDoubleList(map['mean'], fieldName: '$fieldName.mean');
    final std = _requireDoubleList(map['std'], fieldName: '$fieldName.std');
    if (mean.length != 3 || std.length != 3) {
      throw ModelContractException(
        '$fieldName mean/std must each contain 3 values.',
      );
    }
    if (std.any((item) => item == 0)) {
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

  static Map<DocumentFaceSourceType, (double, double, double, double)>
      _parseRoiByType(
    Map<String, dynamic> extractionMap, {
    required String fieldName,
  }) {
    final raw = extractionMap['roi_by_type'];
    if (raw is! Map) {
      throw ModelContractException('$fieldName must be a JSON object.');
    }

    final roiMap = <DocumentFaceSourceType, (double, double, double, double)>{};
    for (final entry in raw.entries) {
      final key = _parseDocumentType(entry.key.toString());
      final values = _requireDoubleList(
        entry.value,
        fieldName: '$fieldName.${entry.key}',
      );
      if (values.length != 4) {
        throw ModelContractException(
          '$fieldName.${entry.key} must have 4 normalized values.',
        );
      }
      roiMap[key] = (values[0], values[1], values[2], values[3]);
    }

    if (!roiMap.containsKey(DocumentFaceSourceType.unknown)) {
      throw ModelContractException(
        '$fieldName must include an "unknown" ROI.',
      );
    }
    return roiMap;
  }

  static DocumentFaceSourceType _parseDocumentType(String value) {
    switch (value) {
      case 'nin_smart':
        return DocumentFaceSourceType.ninSmart;
      case 'voter_card':
        return DocumentFaceSourceType.voterCard;
      case 'drivers_license':
        return DocumentFaceSourceType.driversLicense;
      case 'passport':
        return DocumentFaceSourceType.passport;
      case 'unknown':
        return DocumentFaceSourceType.unknown;
      default:
        return DocumentFaceSourceType.unknown;
    }
  }
}
