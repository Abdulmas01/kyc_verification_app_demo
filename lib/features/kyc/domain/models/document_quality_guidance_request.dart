import 'package:kyc_verification_app_demo/core/ml/quality_model.dart';

import '../../presentation/models/kyc_capture_config.dart';

class DocumentQualityGuidanceRequest {
  const DocumentQualityGuidanceRequest({
    required this.quality,
    required this.config,
    required this.usesQualityGate,
  });

  final QualityResult quality;
  final DocumentCaptureConfig config;
  final bool usesQualityGate;
}
