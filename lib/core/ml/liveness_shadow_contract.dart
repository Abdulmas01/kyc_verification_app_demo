import 'dart:convert';

import 'package:flutter/services.dart';

import '../utils/app_assets.dart';

class LivenessShadowContract {
  const LivenessShadowContract({
    required this.inputWidth,
    required this.inputHeight,
    required this.normalizationMode,
    this.liveClassIndex = 1,
    this.threshold,
    this.sourceRunId,
  });

  final int inputWidth;
  final int inputHeight;
  final String normalizationMode;
  final int liveClassIndex;
  final double? threshold;
  final String? sourceRunId;

  static const LivenessShadowContract fallback = LivenessShadowContract(
    inputWidth: 128,
    inputHeight: 128,
    normalizationMode: 'zero_to_one',
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
    final inputShape = (json['input_shape'] as List?)?.cast<dynamic>();
    final width = _readInt(json['input_width']) ??
        (inputShape != null && inputShape.length >= 4
            ? _readInt(inputShape[2])
            : null) ??
        fallback.inputWidth;
    final height = _readInt(json['input_height']) ??
        (inputShape != null && inputShape.length >= 4
            ? _readInt(inputShape[1])
            : null) ??
        fallback.inputHeight;

    return LivenessShadowContract(
      inputWidth: width,
      inputHeight: height,
      normalizationMode:
          (json['normalization_mode'] ?? fallback.normalizationMode).toString(),
      liveClassIndex:
          _readInt(json['live_class_index']) ?? fallback.liveClassIndex,
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
}
