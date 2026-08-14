import 'package:kyc_verification_app_demo/core/ml/liveness_shadow_model.dart';

import '../../domain/enums/liveness_mode.dart';
import '../../domain/enums/liveness_reason_code.dart';
import '../../domain/models/liveness_evaluation_result.dart';
import '../../domain/models/mobile_liveness_shadow_request.dart';

class MobileLivenessShadowService {
  const MobileLivenessShadowService();

  Future<LivenessEvaluationResult?> run(
    MobileLivenessShadowRequest request,
  ) async {
    final selfiePath = request.selfiePath;
    final config = request.config;
    if (!config.enabled) {
      return null;
    }

    try {
      final prediction = await LivenessShadowModel.predictFromFile(selfiePath);
      if (prediction == null) {
        return LivenessEvaluationResult.runtimeFailed(
          mode: LivenessMode.shadow,
          reasonCode: LivenessReasonCode.modelUnavailable,
          metadata: {
            'message':
                'Shadow liveness asset is missing or could not be loaded.',
          },
        );
      }

      return LivenessEvaluationResult.needsBackendReview(
        mode: LivenessMode.shadow,
        reasonCode: LivenessReasonCode.needsBackendReview,
        score: prediction.liveScore,
        latencyMs: prediction.latencyMs,
        metadata: const {
          'source': 'mobile_shadow_model',
        },
      );
    } catch (error) {
      if (!config.failOpen) {
        rethrow;
      }
      return LivenessEvaluationResult.runtimeFailed(
        mode: LivenessMode.shadow,
        reasonCode: LivenessReasonCode.runtimeFailed,
        metadata: {
          'message': error.toString(),
        },
      );
    }
  }
}
