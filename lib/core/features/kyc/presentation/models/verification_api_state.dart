import 'package:flutter/foundation.dart';

import '../../domain/models/verification_result.dart';

enum VerificationApiStatus {
  idle,
  uploading,
  polling,
  data,
  error,
  timeout,
}

@immutable
class VerificationApiState {
  final VerificationApiStatus status;
  final double uploadProgress;
  final VerificationResult? result;
  final Object? error;
  final StackTrace? stackTrace;

  const VerificationApiState._({
    required this.status,
    this.uploadProgress = 0,
    this.result,
    this.error,
    this.stackTrace,
  });

  const VerificationApiState.idle()
      : this._(status: VerificationApiStatus.idle);

  const VerificationApiState.uploading({required double progress})
      : this._(
          status: VerificationApiStatus.uploading,
          uploadProgress: progress,
        );

  const VerificationApiState.polling()
      : this._(status: VerificationApiStatus.polling);

  const VerificationApiState.data(VerificationResult result)
      : this._(
          status: VerificationApiStatus.data,
          result: result,
        );

  const VerificationApiState.error(Object error, [StackTrace? stackTrace])
      : this._(
          status: VerificationApiStatus.error,
          error: error,
          stackTrace: stackTrace,
        );

  const VerificationApiState.timeout()
      : this._(status: VerificationApiStatus.timeout);

  bool get isTerminal =>
      status == VerificationApiStatus.data ||
      status == VerificationApiStatus.error ||
      status == VerificationApiStatus.timeout;
}
