import 'package:kyc_verification_app_demo/core/network/request_cancel_token.dart';

class FetchResultRequest {
  final String sessionToken;
  final RequestCancelToken? cancelToken;

  const FetchResultRequest({
    required this.sessionToken,
    this.cancelToken,
  });
}
