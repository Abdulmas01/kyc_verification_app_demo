import 'dart:convert';

import 'package:flutter/services.dart';

import '../utils/app_assets.dart';

enum ModelTensorLayout { nchw, nhwc }

class DocumentQualityContract {
  const DocumentQualityContract({
    required this.classes,
    required this.inputWidth,
    required this.inputHeight,
    required this.inputChannels,
    required this.layout,
    required this.normalization,
    this.sourceRunId,
    this.sha256,
    this.artifact,
  });

  final List<String> classes;
  final int inputWidth;
  final int inputHeight;
  final int inputChannels;
  final ModelTensorLayout layout;
  final String normalization;
  final String? sourceRunId;
  final String? sha256;
  final String? artifact;

  static const DocumentQualityContract fallback = DocumentQualityContract(
    classes: ['GOOD', 'BLURRY', 'GLARE', 'DARK', 'NO_DOCUMENT'],
    inputWidth: 224,
    inputHeight: 224,
    inputChannels: 3,
    layout: ModelTensorLayout.nhwc,
    normalization: 'ImageNet mean/std',
  );

  static Future<DocumentQualityContract> load() async {
    try {
      final jsonString = await rootBundle.loadString(
        AppAssets.docQualityContract,
      );
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return fallback;
      }
      return DocumentQualityContract.fromJson(decoded);
    } catch (_) {
      return fallback;
    }
  }

  factory DocumentQualityContract.fromJson(Map<String, dynamic> json) {
    final input = json['input'];
    final output = json['output'];
    final inputMap = input is Map ? Map<String, dynamic>.from(input) : const {};
    final outputMap =
        output is Map ? Map<String, dynamic>.from(output) : const {};
    final shape = (inputMap['shape'] as List?)?.cast<dynamic>() ?? const [];
    final classes = _readStringList(outputMap['classes']) ??
        _readStringList(json['classes']) ??
        fallback.classes;
    final layout = _inferLayout(shape);

    return DocumentQualityContract(
      classes: classes,
      inputWidth: _inferWidth(shape, layout) ?? fallback.inputWidth,
      inputHeight: _inferHeight(shape, layout) ?? fallback.inputHeight,
      inputChannels: _inferChannels(shape, layout) ?? fallback.inputChannels,
      layout: layout,
      normalization:
          (inputMap['normalization'] ?? fallback.normalization).toString(),
      sourceRunId: json['source_run_id']?.toString(),
      sha256: json['sha256']?.toString(),
      artifact: json['artifact']?.toString(),
    );
  }

  static List<String>? _readStringList(Object? value) {
    if (value is! List) return null;
    return value.map((item) => item.toString()).toList(growable: false);
  }

  static ModelTensorLayout _inferLayout(List<dynamic> shape) {
    if (shape.length >= 4) {
      final second = _readInt(shape[1]);
      final last = _readInt(shape[3]);
      if (second == 3) return ModelTensorLayout.nchw;
      if (last == 3) return ModelTensorLayout.nhwc;
    }
    return fallback.layout;
  }

  static int? _inferWidth(List<dynamic> shape, ModelTensorLayout layout) {
    if (shape.length < 4) return null;
    return layout == ModelTensorLayout.nchw
        ? _readInt(shape[3])
        : _readInt(shape[2]);
  }

  static int? _inferHeight(List<dynamic> shape, ModelTensorLayout layout) {
    if (shape.length < 4) return null;
    return layout == ModelTensorLayout.nchw
        ? _readInt(shape[2])
        : _readInt(shape[1]);
  }

  static int? _inferChannels(List<dynamic> shape, ModelTensorLayout layout) {
    if (shape.length < 4) return null;
    return layout == ModelTensorLayout.nchw
        ? _readInt(shape[1])
        : _readInt(shape[3]);
  }

  static int? _readInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
