import '../../presentation/models/kyc_capture_config.dart';

class MobileLivenessShadowRequest {
  const MobileLivenessShadowRequest({
    required this.selfiePath,
    required this.config,
  });

  final String selfiePath;
  final MobileLivenessShadowConfig config;
}
