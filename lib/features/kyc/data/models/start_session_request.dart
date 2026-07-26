import 'package:kyc_verification_app_demo/core/network/request_cancel_token.dart';

class StartSessionRequest {
  final String appVersion;
  final String deviceOs;
  final String modelVersion;
  final RequestCancelToken? cancelToken;

  const StartSessionRequest({
    required this.appVersion,
    required this.deviceOs,
    this.modelVersion = 'v1.0.0',
    this.cancelToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'app_version': appVersion,
      'device_os': deviceOs,
      'model_version': modelVersion,
    };
  }
}
