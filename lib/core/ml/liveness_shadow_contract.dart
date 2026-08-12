import 'dart:convert';

import 'package:flutter/services.dart';

import '../utils/app_assets.dart';

class LivenessShadowContract {
  const LivenessShadowContract({
    required this.inputWidth,
    required this.inputHeight,
    required this.inputLayout,
    required this.inputScale,
    required this.inputMean,
    required this.inputStd,
    required this.faceCropRequired,
    required this.faceCropMargin,
    required this.multipleFacesPolicy,
    required this.outputRepresentation,
    this.liveClassIndex = 1,
    this.threshold,
    this.sourceRunId,
  });

  final int inputWidth;
  final int inputHeight;
  final String inputLayout;
  final double inputScale;
  final List<double> inputMean;
  final List<double> inputStd;
  final bool faceCropRequired;
  final double faceCropMargin;
  final String multipleFacesPolicy;
  final String outputRepresentation;
  final int liveClassIndex;
  final double? threshold;
  final String? sourceRunId;

  static const LivenessShadowContract fallback = LivenessShadowContract(
    inputWidth: 128,
    inputHeight: 128,
    inputLayout: 'NHWC',
    inputScale: 1 / 255,
    inputMean: [0.485, 0.456, 0.406],
    inputStd: [0.229, 0.224, 0.225],
    faceCropRequired: true,
    faceCropMargin: 0.0,
    multipleFacesPolicy: 'reject',
    outputRepresentation: 'logit',
    liveClassIndex: 1,
  );

  static Future<LivenessShadowContract> load() async {
    try {
      final jsonString = await rootBundle.loadString(
        AppAssets.livenessShadowContract,
      );
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return fallback;
      }
      return LivenessShadowContract.fromJson(decoded);
    } catch (_) {
      return fallback;
    }
  }

  factory LivenessShadowContract.fromJson(Map<String, dynamic> json) {
    final inputMap = Map<String, dynamic>.from(
      (json['input'] as Map?) ?? const <String, dynamic>{},
    );
    final outputMap = Map<String, dynamic>.from(
      (json['output'] as Map?) ?? const <String, dynamic>{},
    );
    final faceCropMap = Map<String, dynamic>.from(
      (json['face_crop'] as Map?) ?? const <String, dynamic>{},
    );
    final normalizationMap = Map<String, dynamic>.from(
      (inputMap['normalization'] as Map?) ?? const <String, dynamic>{},
    );

    final inputShape = (inputMap['shape'] as List?)?.cast<dynamic>();
    final width = _readInt(inputMap['input_width']) ??
        (inputShape != null && inputShape.length >= 4
            ? _readInt(inputShape[2])
            : null) ??
        fallback.inputWidth;
    final height = _readInt(inputMap['input_height']) ??
        (inputShape != null && inputShape.length >= 4
            ? _readInt(inputShape[1])
            : null) ??
        fallback.inputHeight;

    return LivenessShadowContract(
      inputWidth: width,
      inputHeight: height,
      inputLayout: (inputMap['layout'] ?? fallback.inputLayout).toString(),
      inputScale: _readDouble(normalizationMap['scale']) ?? fallback.inputScale,
      inputMean:
          _readDoubleList(normalizationMap['mean']) ?? fallback.inputMean,
      inputStd: _readDoubleList(normalizationMap['std']) ?? fallback.inputStd,
      faceCropRequired:
          _readBool(faceCropMap['required']) ?? fallback.faceCropRequired,
      faceCropMargin:
          _readDouble(faceCropMap['margin']) ?? fallback.faceCropMargin,
      multipleFacesPolicy:
          (faceCropMap['multiple_faces'] ?? fallback.multipleFacesPolicy)
              .toString(),
      outputRepresentation:
          (outputMap['representation'] ?? fallback.outputRepresentation)
              .toString(),
      liveClassIndex:
          _readInt(outputMap['live_class']) ?? fallback.liveClassIndex,
      threshold: _readDouble(json['threshold']),
      sourceRunId: json['source_run_id']?.toString(),
    );
  }

  static int? _readInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _readDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static List<double>? _readDoubleList(Object? value) {
    if (value is! List) return null;
    return value
        .map((item) => _readDouble(item))
        .whereType<double>()
        .toList(growable: false);
  }

  static bool? _readBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }
}
