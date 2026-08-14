import 'package:kyc_verification_app_demo/core/ml/liveness_shadow_model.dart';

import '../../presentation/models/kyc_capture_config.dart';

class MobileLivenessShadowResult {
  const MobileLivenessShadowResult.success({
    required this.score,
    required this.latencyMs,
  }) : errorMessage = null;

  const MobileLivenessShadowResult.unavailable(this.errorMessage)
      : score = null,
        latencyMs = null;

  final double? score;
  final double? latencyMs;
  final String? errorMessage;

  bool get isAvailable => score != null && latencyMs != null;
}

class MobileLivenessShadowService {
  const MobileLivenessShadowService();

  Future<MobileLivenessShadowResult?> run({
    required String selfiePath,
    required MobileLivenessShadowConfig config,
  }) async {
    if (!config.enabled) {
      return null;
    }

    try {
      final prediction = await LivenessShadowModel.predictFromFile(selfiePath);
      if (prediction == null) {
        return const MobileLivenessShadowResult.unavailable(
          'Shadow liveness asset is missing or could not be loaded.',
        );
      }

      return MobileLivenessShadowResult.success(
        score: prediction.liveScore,
        latencyMs: prediction.latencyMs,
      );
    } catch (error) {
      if (!config.failOpen) {
        rethrow;
      }
      return MobileLivenessShadowResult.unavailable(error.toString());
    }
  }
}
