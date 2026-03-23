import 'package:kyc_verification_app_demo/core/network/request_cancel_token.dart';

class FetchResultRequest {
  final String sessionId;
  final RequestCancelToken? cancelToken;

  const FetchResultRequest({
    required this.sessionId,
    this.cancelToken,
  });
}
