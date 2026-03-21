import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/app_assets.dart';

class ModelLoader {
  static Interpreter? _docQuality;
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
}
