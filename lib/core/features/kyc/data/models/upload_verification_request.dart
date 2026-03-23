import 'dart:io';

import 'package:kyc_verification_app_demo/core/network/request_cancel_token.dart';

class UploadVerificationRequest {
  final String sessionToken;
  final File documentImage;
  final File selfieImage;
  final void Function(int sent, int total)? onSendProgress;
  final RequestCancelToken? cancelToken;

  const UploadVerificationRequest({
    required this.sessionToken,
    required this.documentImage,
    required this.selfieImage,
    this.onSendProgress,
    this.cancelToken,
  });
}
