import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/app_assets.dart';

class ModelLoader {
  static Interpreter? _docQuality;
  static Interpreter? _livenessShadow;
  static bool _livenessShadowLoadAttempted = false;
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
}
