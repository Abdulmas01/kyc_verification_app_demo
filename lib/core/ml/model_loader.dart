import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/app_assets.dart';

class ModelLoader {
  static Interpreter? _docQuality;
  static Interpreter? _livenessShadow;
  static Interpreter? _faceEmbedding;
  static bool _livenessShadowLoadAttempted = false;
  static bool _faceEmbeddingLoadAttempted = false;
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    _docQuality = await Interpreter.fromAsset(AppAssets.docQualityModel);
    _loaded = true;
  }

  static Interpreter get docQuality {
    final model = _docQuality;
    if (model == null) {
      throw StateError('ModelLoader not initialized');
    }
    return model;
  }

  /// Loads the optional on-device liveness shadow model on demand.
  ///
  /// The thesis prototype keeps backend liveness authoritative. This mobile
  /// model exists only for runtime validation, latency benchmarking, and
  /// mobile-vs-backend score comparison.
  static Future<Interpreter?> loadOptionalLivenessShadow() async {
    if (_livenessShadow != null) return _livenessShadow;
    if (_livenessShadowLoadAttempted) return null;
    _livenessShadowLoadAttempted = true;

    try {
      _livenessShadow =
          await Interpreter.fromAsset(AppAssets.livenessShadowModel);
      return _livenessShadow;
    } catch (_) {
      return null;
    }
  }

  /// Loads the optional mobile face embedding model on demand.
  ///
  /// This is a research/mobile-candidate model for thesis benchmarking and
  /// future SDK work. Backend verification remains authoritative for now.
  static Future<Interpreter?> loadOptionalFaceEmbedding() async {
    if (_faceEmbedding != null) return _faceEmbedding;
    if (_faceEmbeddingLoadAttempted) return null;
    _faceEmbeddingLoadAttempted = true;

    try {
      _faceEmbedding =
          await Interpreter.fromAsset(AppAssets.faceEmbeddingModel);
      return _faceEmbedding;
    } catch (_) {
      return null;
    }
  }
}
